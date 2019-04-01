BITFILE=$1
vivado -mode batch -notrace -nojournal -log ./log/vivado.log -source program.tcl -tclargs --bitfile $BITFILE
