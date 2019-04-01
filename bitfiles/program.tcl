if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--bitfile"   { incr i; set bitfile [lindex $::argv $i] }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

puts "Programming bitfile $bitfile"

open_hw
connect_hw_server
open_hw_target

set_property PROGRAM.FILE $bitfile [get_hw_devices xcku115_0]
# set_property PROBES.FILE {/home/hardik/workspace/vivado_projects/bitfusion.vivado/bitfusion.vivado.runs/impl_1/ku115_wrapper.ltx} [get_hw_devices xcku115_0]
# set_property FULL_PROBES.FILE {/home/hardik/workspace/vivado_projects/bitfusion.vivado/bitfusion.vivado.runs/impl_1/ku115_wrapper.ltx} [get_hw_devices xcku115_0]
current_hw_device [get_hw_devices xcku115_0]
refresh_hw_device [lindex [get_hw_devices xcku115_0] 0]
program_hw_devices [get_hw_devices xcku115_0]
refresh_hw_device [lindex [get_hw_devices xcku115_0] 0]
