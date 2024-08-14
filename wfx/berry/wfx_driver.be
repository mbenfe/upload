#---------------------------------#
# VERSION 1.0 WFX                 #
#---------------------------------#

import mqtt
import string
import json


class WFX
    var mapID
    var mapFunc
    var ser1
    var ser2

    var rx1
    var tx1    
    var rx2    
    var tx2    
       
    var rst_1  
    var bsl_1  
    var rst_2  
    var bsl_2   
    var client 
    var ville
    var device1
    var device2
    var topic 

    var logger
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
        self.client=jsonmap["client"]
        print('client:',self.client)
        self.ville=jsonmap["ville"]
        print('ville:',self.ville)
        self.device1=jsonmap["device1"]
        print('device1:',self.device1)
        self.device2=jsonmap["device2"]
        print('device2:',self.device2)
    end

    def init()
        import conso
        self.conso = conso
        import logger
        self.logger = logger

        self.rst_1=22   
        self.bsl_1=0   
        self.rst_2=2   
        self.bsl_2=14   
    
        self.rx1=3    
        self.tx1=1    
        self.rx2=13    
        self.tx2=12    
        
        print('DRIVER: serial init done')
        gpio.pin_mode(self.rx1,gpio.INPUT_PULLUP)
        gpio.pin_mode(self.tx1,gpio.PULLUP)
        gpio.pin_mode(self.rx2,gpio.INPUT_PULLUP)
        gpio.pin_mode(self.tx2,gpio.PULLUP)
        self.ser1 = serial(self.rx1,self.tx1,115200,serial.SERIAL_8N1)
        self.ser2 = serial(self.rx2,self.tx2,115200,serial.SERIAL_8N1)
    
        # setup boot pins for stm32: reset disable & boot normal

        gpio.pin_mode(self.rst_1,gpio.OUTPUT)
        gpio.pin_mode(self.bsl_1,gpio.OUTPUT)
        gpio.pin_mode(self.rst_2,gpio.OUTPUT)
        gpio.pin_mode(self.bsl_2,gpio.OUTPUT)
        gpio.digital_write(self.bsl_1, 0)
        gpio.digital_write(self.rst_1, 1)
        gpio.digital_write(self.bsl_2, 0)
        gpio.digital_write(self.rst_2, 1)

    #    tasmota.add_fast_loop(/-> self.fast_loop())
    end

    def fast_loop()
        self.read_uart1(2)
    end

    def read_uart1(timeout)
        var mystring
        var mylist
        var numitem
        var myjson
        var due
        var topic
        var buffer
        if self.ser1.available()
            due = tasmota.millis() + timeout
            while !tasmota.time_reached(due) end
            buffer = self.ser1.read()
            self.ser1.flush()
            mystring = buffer.asstring()
            mylist = string.split(mystring,'\n')
            numitem= size(mylist)
            for i: 0..numitem-2
                if mylist[i][0] == 'C'
                    self.conso.update(mylist[i])
                    print(mylist[i])
                elif mylist[i][0] == 'W'
                    self.logger.log_data(mylist[i])
 #                       print(mylist[i])
                else
                    print('WFX->',mylist[i])
                end
            end
        end
    end

    def read_uart2(timeout)
        var mystring
        var mylist
        var numitem
        var myjson
        var due
        var topic
        var buffer
        if self.ser2.available()
            due = tasmota.millis() + timeout
            while !tasmota.time_reached(due) end
            buffer = self.ser2.read()
            self.ser2.flush()
            mystring = buffer.asstring()
            mylist = string.split(mystring,'\n')
            numitem= size(mylist)
            for i: 0..numitem-2
                if mylist[i][0] == 'C'
                    self.conso.update(mylist[i])
                    print(mylist[i])
                elif mylist[i][0] == 'W'
                    self.logger.log_data(mylist[i])
 #                       print(mylist[i])
                else
                    print('WFX->',mylist[i])
                end
            end
        end
    end

    def midnight()
        self.conso.mqtt_publish('all')
   end

   def hour()
       var now = tasmota.rtc()
       var rtc=tasmota.time_dump(now['local'])
       var hour = rtc['hour']
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

wfx = WFX()
tasmota.add_driver(wfx)
tasmota.add_fast_loop(/-> wfx.fast_loop())
tasmota.add_cron("59 59 23 * * *",  /-> wfx.midnight(), "every_day")
tasmota.add_cron("59 59 * * * *",   /-> wfx.hour(), "every_hour")
tasmota.add_cron("01 01 */4 * * *",   /-> wfx.every_4hours(), "every_4_hours")
return wfx