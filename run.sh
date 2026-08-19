cd /home/runner
export PATH=/usr/local/bin:/usr/bin:/bin:/tool/pandora64/bin:/usr/local/bin/verilator/bin:/usr/local/bin
export EDATOOL=verilator
export HOME=/home/runner
verilator --prefix Vsim --binary --build-jobs 0 '--build' '--trace-vcd' '--quiet-build' '-Wno-fatal' '--timescale' '1ns/1ns' design.sv testbench.sv  && obj_dir/Vsim  ; echo 'Creating result.zip...' && zip -r /tmp/tmp_zip_file_123play.zip . && mv /tmp/tmp_zip_file_123play.zip result.zip