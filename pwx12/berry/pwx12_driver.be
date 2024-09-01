#---------------------------------#
# PWX12_DRIVER.BE 1.0 PWX12       #
#---------------------------------#

import mqtt
import string
import json

class PWX12
    var ser
    var rx
    var tx
    var bsl
    var rst

    var logger
    var root
    var topic 
    var conso

    def loadconfig()
        import json
        var jsonstring
        var file 
        file = open("esp32.cfg","rt")
        if file.size() == 0
            print('creat esp32 config file')
            file = open("esp32.cfg","wt")
            jsonstring=string.format("{\"ville\":\"unknown\",\"client\":\"inter\",\"device\":\"unknown\"}")
            file.write(jsonstring)
            file.close()
            file=open("esp32.cfg","rt")
        end
        var buffer = file.read()
        var jsonmap = json.load(buffer)
        global.client=jsonmap["client"]
        print('client:',global.client)
        global.ville=jsonmap["ville"]
        print('ville:',global.ville)
        global.device=jsonmap["device"]
        print('device:',global.device)
    end

    def init()
        self.loadconfig()
        import conso
        self.conso = conso
        import logger
        self.logger = logger
        self.rx=3
        self.tx=1
        self.rst=2
        self.bsl=13

        print('DRIVER: serial init done')
        print('heap:',tasmota.get_free_heap())
        self.ser = serial(self.rx,self.tx,115200,serial.SERIAL_8N1) 
        # setup boot pins for stm32: reset disable & boot normal
        gpio.pin_mode(self.rst,gpio.OUTPUT)
        gpio.pin_mode(self.bsl,gpio.OUTPUT)
        gpio.digital_write(self.bsl, 0)
        gpio.digital_write(self.rst, 1)
   end

    def fast_loop()
        self.read_uart(2)
    end

    def read_uart(timeout)
        if self.ser.available()
            if self.ser.available()
                var due = tasmota.millis() + timeout
                while !tasmota.time_reached(due) end
                var buffer = self.ser.read()
                self.ser.flush()
                var mystring = buffer.asstring()
                var mylist = string.split(mystring,'\n')
                var numitem= size(mylist)
                for i: 0..numitem-2
                    if mylist[i][0] == 'C'
                        self.conso.update(mylist[i])
                        print(mylist[i])
                    elif mylist[i][0] == 'W'
                        self.logger.log_data(mylist[i])
                        var topic
                        var split
                        split = string.split(mylist[i],':')
                        var ligne
                        for j:0..2
                            topic = string.format("gw/%s/%s/%s-%d/tele/POWER",global.client,global.ville,global.device,j+1)
                            ligne = string.format('{"Device": "%s","Name":"%s","ActivePower":%.1f}',global.device,global.configjson[global.device]["root"][j],split[j+1])
                            mqtt.publish(topic,ligne,true)
                        end
                    else
                        print('PWX12->',mylist[i])
                    end
                end
            end
    
        end
    end

    def midnight()
         self.conso.mqtt_publish('all')
    end

    def hour()
        var now = tasmota.rtc()
        var rtc=tasmota.time_dump(now["local"])
        var hour = rtc["hour"]
        # publish if not midnight
        if hour != 23
            self.conso.mqtt_publish('hours')
        end
    end

    def every_4hours()
        self.conso.sauvegarde()
    end

    def testlog()
        self.logger.store()
    end

end

pwx12 = PWX12()
tasmota.add_driver(pwx12)
tasmota.add_fast_loop(/-> pwx12.fast_loop())
tasmota.add_cron("59 59 23 * * *",  /-> pwx12.midnight(), "every_day")
tasmota.add_cron("59 59 * * * *",   /-> pwx12.hour(), "every_hour")
tasmota.add_cron("01 01 */4 * * *",   /-> pwx12.every_4hours(), "every_4_hours")

return pwx12