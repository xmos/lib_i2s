import xmostest, os, subprocess, re, shutil

sr_range = (96000, 192000)
i2s_range = (1, 2, 3, 4)
burn_range = (0, 5, 7)

command_line_build = """ "make" "-B" """
command_line_sim = """ "xsim" "--plugin" "LoopbackPort.dll" "-port tile[0] XS1_PORT_1A 1 0 -port tile[0] XS1_PORT_1G 1 0 " "--max-cycles" "50000000" "--xscope" "-xe '/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/bin/AN00162_i2s_loopback_demo.xe' -offline  xscope.xmt" "/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/bin/AN00162_i2s_loopback_demo.xe" """
                                                        
#command_line = """ "xsim" "--trace-plugin" "VcdPlugin.dll" "-o '/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/AN00162_i2s_loopback_demo.vcd' -xe '/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/bin/AN00162_i2s_loopback_demo.xe' -core tile[0] -ports -ports-detailed -cores -instructions " "--plugin" "LoopbackPort.dll" "-port tile[0] XS1_PORT_1A 1 0 -port tile[0] XS1_PORT_1G 1 0 " "--max-cycles" "5000000" "--xscope" "-xe '/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/bin/AN00162_i2s_loopback_demo.xe' -offline  xscope.xmt" "/Users/Ed/apps/scratch/lib_i2s_upgrade/a_dir/lib_i2s/examples/AN00162_i2s_loopback_demo/bin/AN00162_i2s_loopback_demo.xe" """

result = ""

for sr in sr_range:
    for i2s in i2s_range:
        for burn in burn_range:

            cmd_line_sim_split = re.findall('"([^"]*)"', command_line_sim)
            cmd_line_build_split = re.findall('"([^"]*)"', command_line_build)

            line = 'EXTRA_FLAGS = -DSAMPLE_FREQUENCY='+str(sr)+' -DNUM_I2S_LINES='+str(i2s)+' -DBURN_THREADS='+str(burn)+'\n'
            
            shutil.copy("Makefile", "Makefile.bak")
            
            #open makefile
            Makefile = open("Makefile", "r+")
            contents = ""
            contents = Makefile.readlines()
            
            #insert extra line at 0
            contents.insert(0, line)
            contents = "".join(contents)
            Makefile.seek(0,0)
            Makefile.write(contents)
            Makefile.close()
            
            #print cmd_line_build_split
            
            #build
            proc = subprocess.Popen(cmd_line_build_split, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            tmp = proc.stdout.read()
            if not tmp.find("Build Complete"):
                    print "Build fail"
                    exit()



            #restore old makefile
            shutil.copy("Makefile.bak", "Makefile")
        
            #run sim
            proc2 = subprocess.Popen(cmd_line_sim_split, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            tmp2 = proc2.stdout.read() + proc2.stderr.read()
            try:
                ticks = int(tmp2.split("=",1)[1])
            except:
                print "Could not extract value from line " + tmp2
            print ("SR: %i, I2S: %i, BURN: %i, Ticks: %i" % (sr, i2s, burn, ticks))



