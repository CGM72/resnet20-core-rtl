    // --------------------------------
    // Expected values and output order
    // --------------------------------
    word_t directed_expected[0:1];
    word_t actual[0:MAX_TENSOR_WORDS-1];
    int pending[0:MAX_TENSOR_WORDS-1];
    bit scheduled[0:MAX_TENSOR_WORDS-1];
    int queued, received, expected_count, compare_width, compare_channels;
    longint elapsed, deadline;
    longint cycle, first_input_cycle, last_output_cycle, inference_start_cycle;
    bit comparing;
    bit check_directed;
    string compare_name;

    task automatic begin_compare(input string name, input int width, channels, count,
                                 input longint cycle_budget, input bit directed = 0);
        @(negedge clk);
        in_enable = 0;
        compare_name = name;
        compare_width = width;
        compare_channels = channels;
        expected_count = count;
        queued = 0;
        received = 0;
        elapsed = 0;
        first_input_cycle = -1;
        deadline = cycle_budget;
        check_directed = directed;
        for (int i = 0; i < count; i++) scheduled[i] = 0;
        comparing = 1;
    endtask

    task automatic queue_output(input int index);
        if (index < 0 || index >= expected_count || queued >= expected_count || scheduled[index])
            $fatal(1, "%s: invalid or duplicate output index %0d", compare_name, index);
        scheduled[index] = 1;
        pending[queued] = index;
        queued++;
    endtask

    // --------------------------------
    // Output sampling and diagnostics
    // --------------------------------
    always @(posedge clk) begin : observe_output
        int index, y, x, oc;
        cycle++;
        if (nrst) begin
            if (comparing) begin
                if (in_enable && first_input_cycle < 0)
                    first_input_cycle = cycle;
                elapsed++;
                if (elapsed > deadline)
                    $fatal(1, "%s: timeout after %0d cycles (%0d/%0d outputs)",
                           compare_name, elapsed, received, expected_count);
            end
            if (out_enable === 1'b1) begin
                if (!comparing || received >= queued)
                    $fatal(1, "%s: unexpected or early output at sample %0d", compare_name, received);
                // Scheduled indices map stream order to HWC tensor storage.
                index = pending[received];
                if ($isunknown(out_data))
                    $fatal(1, "%s: unknown data at output index %0d", compare_name, index);
                if (check_directed && out_data !== directed_expected[index]) begin
                    oc = index % compare_channels;
                    x = (index / compare_channels) % compare_width;
                    y = index / (compare_width * compare_channels);
                    $fatal(1, "%s (y=%0d x=%0d oc=%0d): expected %0d, got %0d",
                           compare_name, y, x, oc, directed_expected[index], out_data);
                end
                actual[index] = out_data;
                received++;
                last_output_cycle = cycle;
            end else if (out_enable !== 1'b0) begin
                $fatal(1, "%s: unknown out_enable", compare_name);
            end
        end
    end

    task automatic finish_compare;
        repeat (CORE_PIPELINE_CYCLES + 1) begin
            @(negedge clk);
            in_enable = 0;
        end
        if (received != expected_count || queued != expected_count)
            $fatal(1, "%s: received %0d, scheduled %0d, expected %0d",
                   compare_name, received, queued, expected_count);
        comparing = 0;
        $display("[ PASS ] %s (%0d words, %0d cycles)", compare_name, received, elapsed);
    endtask

    // --------------------------------
    // Final logit SNR
    // --------------------------------
    function automatic word_t format_logit(input word_t value);
        int sample, divisor;

        sample = int'(value);
        if (OUTPUT_FRAC_BITS < CORE_FRAC_BITS) begin
            divisor = 1 << (CORE_FRAC_BITS - OUTPUT_FRAC_BITS);
            if (sample < 0) sample = -((-sample + divisor / 2) / divisor);
            else sample = (sample + divisor / 2) / divisor;
        end else begin
            sample = sample <<< (OUTPUT_FRAC_BITS - CORE_FRAC_BITS);
        end

        if (sample > 32767) return 32767;
        if (sample < -32768) return -32768;
        return word_t'(sample);
    endfunction

    task automatic dump_layer_output(input int index);
        string path;
        int fd;
        path = $sformatf("%s/layer_%02d_actual.hex", snr_dir, index);
        fd = $fopen(path, "w");
        if (!fd) $fatal(1, "Cannot write %s", path);
        for (int i = 0; i < expected_count; i++)
            $fdisplay(fd, "%04h", actual[i]);
        $fclose(fd);
    endtask

    task automatic dump_logits;
        int fd;
        fd = $fopen({snr_dir, "/logits_actual.hex"}, "w");
        if (!fd) $fatal(1, "Cannot write logits_actual.hex in %s", snr_dir);
        for (int i = 0; i < LOGIT_COUNT; i++)
            $fdisplay(fd, "%04h", feature[i]);
        $fclose(fd);
        $fdisplay(snr_summary, "%0d %0d", LOGIT_COUNT, OUTPUT_FRAC_BITS);
    endtask

    task automatic check_logit_snr;
        localparam real MIN_SNR_DB = 50.0;
        localparam real OUTPUT_SCALE = 2.0 ** OUTPUT_FRAC_BITS;
        int fd, sample;
        real reference, error_value, signal_power, error_power, snr_db;
        string extra;

        fd = $fopen({vector_dir,"/reference_logits_float.txt"}, "r");
        if (!fd) $fatal(1, "Cannot open float reference logits");
        signal_power = 0.0;
        error_power = 0.0;
        for (int i = 0; i < LOGIT_COUNT; i++) begin
            if ($fscanf(fd, "%f", reference) != 1)
                $fatal(1, "Missing or invalid float reference logit %0d", i);
            sample = int'(feature[i]);
            error_value = reference - ($itor(sample) / OUTPUT_SCALE);
            signal_power += reference * reference;
            error_power += error_value * error_value;
        end
        if ($fscanf(fd, "%s", extra) == 1) $fatal(1, "Extra float reference logits");
        $fclose(fd);

        if (signal_power <= 0.0) $fatal(1, "Float reference logits have no signal power");
        if (error_power == 0.0) begin
            $display("[ PASS ] logit SNR = inf dB (minimum %.2f dB)", MIN_SNR_DB);
        end else begin
            snr_db = 10.0 * $log10(signal_power / error_power);
            if (snr_db < MIN_SNR_DB)
                $fatal(1, "Logit SNR %.2f dB is below %.2f dB", snr_db, MIN_SNR_DB);
            $display("[ PASS ] logit SNR = %.2f dB (minimum %.2f dB)", snr_db, MIN_SNR_DB);
        end
    endtask

    // Independent Python integer oracle: every affine layer must match bit-for-bit.
    task automatic check_layer_reference(input int layer_index);
        int fd;
        logic [15:0] expected_word;
        string path, extra;
        path = $sformatf("%s/expected/layer_%02d.hex", vector_dir, layer_index);
        fd = $fopen(path, "r");
        if (!fd) $fatal(1, "Missing integer layer reference %s", path);
        for (int i = 0; i < expected_count; i++) begin
            if ($fscanf(fd, "%h", expected_word) != 1)
                $fatal(1, "%s: missing expected word %0d", compare_name, i);
            if (actual[i] !== expected_word)
                $fatal(1, "%s word %0d: integer expected=%0d actual=%0d",
                       compare_name, i, $signed(expected_word), actual[i]);
        end
        if ($fscanf(fd, "%s", extra) == 1) $fatal(1, "%s: extra expected words", path);
        $fclose(fd);
        $display("[ PASS ] %s integer reference (%0d words)", compare_name, expected_count);
    endtask
