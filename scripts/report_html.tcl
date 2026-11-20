# Standalone, offline rendering of the Vivado implementation summary.
namespace eval ::fpga {
    proc html_escape {value} {
        return [string map [list & {&amp;} < {&lt;} > {&gt;} {"} {&quot;} {'} {&#39;}] $value]
    }

    proc write_html_report {cfg clock_period directory timing resources} {
        variable root
        set release_version [string trim [read_text_file [file join $root VERSION]]]
        set html {<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ResNet-20 Core | Implementation Report</title>
<style>
:root { font: 14px/1.5 "Segoe UI", Arial, sans-serif; color: #18212b; background: #fff; }
body { max-width: 1200px; margin: 26px auto; padding: 0 20px; }
h1 { margin: 0; font-size: 23px; }
.meta { color: #495465; margin: 4px 0 24px; }
h2 { font-size: 16px; margin: 24px 0 14px; padding-bottom: 5px; border-bottom: 1px solid #c3c9d1; }
.timing { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
h3 { margin: 0; font-size: 14px; border-bottom: 1px solid #c3c9d1; padding-bottom: 4px; }
table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
.metrics th, .metrics td { padding: 5px 3px; }
.metrics th { text-align: left; font-weight: 400; }
.metrics td { text-align: right; white-space: nowrap; }
.metrics tr:first-child td { color: #194ca4; font-weight: 600; }
.status { font-weight: 600; }
.met { color: #206344; }
.violated, .metrics tr:first-child td.violated { color: #a32121; }
.na { color: #576373; }
.resource-wrap { overflow-x: auto; }
.resources th, .resources td { border: 1px solid #c3c9d1; padding: 7px 11px; text-align: right; }
.resources thead { background: #e9edf2; }
.resources thead small { display: block; font-weight: normal; color: #495465; }
.resources tbody { background: #e7efff; }
.resources th:first-child { text-align: left; }
.source { margin-top: 22px; font-size: 12px; color: #495465; overflow-wrap: anywhere; }
@media (max-width: 740px) { .timing { grid-template-columns: 1fr; } }
@media print { body { margin: 0; } .timing { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
</style>
</head>
<body>
<h1>ResNet-20 Core Implementation Report</h1>}
        set part [html_escape [dict get $cfg part]]
        set vivado [html_escape [version -short]]
        append html "\n<p class='meta'>v[html_escape $release_version] &middot; $part &middot; Vivado $vivado &middot; [html_escape $clock_period] ns target &middot; Post-route</p>"
        append html "\n<h2>Design Timing Summary</h2>\n<div class='timing'>"
        foreach {name worst_label total_label} {
            Setup {Worst Negative Slack (WNS)} {Total Negative Slack (TNS)}
            Hold {Worst Hold Slack (WHS)} {Total Hold Slack (THS)}
            {Pulse Width} {Worst Pulse Width Slack (WPWS)} {Total Pulse Width Negative Slack (TPWS)}
        } {
            lassign [dict get $timing $name] worst total failing endpoints status
            set status_class [string map {/ ""} [string tolower $status]]
            append html "\n<section><h3>$name</h3><table class='metrics'><tbody>"
            foreach {label value unit} [list $worst_label $worst ns $total_label $total ns \
                "Number of Failing Endpoints" $failing "" "Total Number of Endpoints" $endpoints ""] {
                if {![string is double -strict $value]} {set unit ""}
                append html "<tr><th scope='row'>$label</th><td class='$status_class'>[html_escape $value] $unit</td></tr>"
            }
            append html "<tr><th scope='row'>Status</th><td class='status $status_class'>$status</td></tr></tbody></table></section>"
        }
        append html "\n</div>\n<h2>Utilization</h2><div class='resource-wrap'><table class='resources'>"
        set header {<thead><tr><th scope="col">Name</th>}
        set counts {<tbody><tr><th scope="row">core</th>}
        set percentages {<tr><th scope="row">Utilization</th>}
        foreach {key label} {LUT {Slice LUTs} FF {Slice Registers} SLICE Slice LOGIC {LUT as Logic} BRAM {Block RAM Tile} DSP DSPs} {
            if {![dict exists $resources $key]} {continue}
            lassign [dict get $resources $key] used available pct
            set pct [expr {$pct eq "" ? "N/A" : "$pct%"}]
            append header "<th scope='col'>$label<small>([html_escape $available])</small></th>"
            append counts "<td>[html_escape $used]</td>"
            append percentages "<td>[html_escape $pct]</td>"
        }
        append html "$header</tr></thead>$counts</tr>$percentages</tr></tbody></table></div>"
        append html "\n<p class='source'>Vivado analysis folder: [html_escape $directory]</p>\n</body></html>\n"

        set output [file join $root reports core_report.html]
        set version_report [file join $root reports generated "v$release_version" core_report.html]
        foreach path [list $output $version_report] {
            set fd [open $path w]
            fconfigure $fd -encoding utf-8
            puts -nonewline $fd $html
            close $fd
        }
        puts "HTML report: $output"
    }
}
