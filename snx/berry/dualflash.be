#------------------------------------------------#
# DUALFLASHER.BE for VSNX 1.0                    #
#------------------------------------------------#

import strict
import math
import string

class dualflasher 

    #################################################################################
    # Flashing from bin files
    #################################################################################
    var filename          # filename of hex file
    var f                 # file object
    var file_bin          
    var flasher           # low-level flasher object (stm32_flasher instance)
    var ser                # serial object
    var debug                   # verbose logs?
 
    var rx_flash    
    var tx_flash 
    var rst_in   
    var bsl_in  
    var rst_out  
    var bsl_out
    var statistic

    var ville
    var device

    def init()
        import json
        var file = open("esp32.cfg","rt")
        var buffer = file.read()
        file.close()
        var myjson=json.load(buffer)
        self.ville=myjson["ville"]
        self.device=myjson["device"]
    end

    def mqttprint(texte)
        import mqtt
        var topic = string.format("gw/inter/%s/%s/tele/PRINT",self.ville,self.device)
        mqtt.publish(topic,texte,true)
    end

    def mydelay(delay)
        var tas = tasmota
        var yield = tasmota.yield
        var count = delay/5
        for i:0..count
            tasmota.delay(5)
            yield(tas) 
        end
    end
 
    def wait_ack(timeout)
        gpio.digital_write(self.statistic, 1)    

        var b = bytes('AA')
        var due = tasmota.millis() + timeout
        while !tasmota.time_reached(due)
          if self.ser.available()
            b = self.ser.read()
          end
          tasmota.delay(5)        # check every 5ms
        end
        if b != nil
            while size(b) > 0 && b[0] == 0
                b = b[1..]
            end
            gpio.digital_write(self.statistic, 0)    
            return b.tohex()
        else
            raise "timeout_error", "serial timeout"
        end
    end
    

    #  def wait_ack(timeout)
    #     var due = tasmota.millis() + timeout
    #     while !tasmota.time_reached(due) end
    #     if self.ser.available()
    #         var b = self.ser.read()
    #         while size(b) > 0 && b[0] == 0
    #             b = b[1..]
    #         end
    #     end
    #     if(size(b)>0)
    #         self.ser.flush()
    #         tasmota.delay(1)
    #         return b.tohex()
    #     end
    #     return 'AA'
    #  end
    

    def initialisation_stm32(rank,stm32)
        import gpio  

        self.rx_flash=36    
        self.tx_flash=1    
        self.rst_in=19   
        self.bsl_in=21   
        self.rst_out=33   
        self.bsl_out=32   
        self.statistic=25
    
 
        var ret
        var rst
        var bsl
        var disable
        self.mqttprint('FLASHER:INITIALISATION:'+str(rank)+':....wait 30 seconds')
        gpio.pin_mode(self.rx_flash,gpio.INPUT)
        gpio.pin_mode(self.tx_flash,gpio.OUTPUT)

        self.ser = serial(self.rx_flash,self.tx_flash,115200,serial.SERIAL_8E1)
        self.ser.flush()
         # reset STM32
         gpio.pin_mode(self.rst_in,gpio.OUTPUT)
         gpio.pin_mode(self.bsl_in,gpio.OUTPUT)
         gpio.pin_mode(self.rst_out,gpio.OUTPUT)
         gpio.pin_mode(self.bsl_out,gpio.OUTPUT)
        #  malek
         gpio.pin_mode(self.statistic,gpio.OUTPUT)
         self.mqttprint('FLASHER:INITIALISATION:'+str(rank)+':stm32 ->'+stm32)
         if stm32=='in'
            self.mqttprint('FLASHER:INITIALISATION:'+str(rank)+':flash RS485 in')
            rst=self.rst_in
            bsl=self.bsl_in
            disable=self.rst_out
         else
            self.mqttprint('FLASHER:INITIALISATION:'+str(rank)+':flash processor output')
            rst=self.rst_out
            bsl=self.bsl_out
            disable=self.rst_in
         end
        #------------- INTIALISE BOOT -------------------------#
        self.mqttprint('FLASHER:INITIALISATION:'+str(rank)+':initialise boot sequence')
        gpio.digital_write(disable, 0)    # put second chip open drain
        gpio.digital_write(rst, 0)    # trigger BSL
        tasmota.delay(50)               # wait 10ms
        gpio.digital_write(bsl, 1)    # trigger BSL
        tasmota.delay(50)               # wait 10ms
        gpio.digital_write(rst, 1)    # trigger BSL
        tasmota.delay(500)               # wait 10ms
        print('bsl/rst done')
        # start boot mode
        self.ser.write(0x7F)
        print('0X7F sent')
        ret = self.wait_ack(50)
        print('boot')
        if str(ret) != '79'
            self.mqttprint('FLASHER:SET BOOT MODE:'+str(rank)+':resp:'+str(ret))
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:SET BOOT MODE:'+str(rank)+':erreur initialisation','NACK'
        else
            self.mqttprint('FLASHER:SET BOOT MODE:'+str(rank)+':ret='+str(ret))
        end
        self.ser.flush()    
        # unpotect memory
        self.ser.write(bytes('738C'))
        ret=self.wait_ack(50)
        # if str(ret) != '79'  # attention seul le premier 79 est pris en compte
        #     self.mqttprint('FLASHER:UNPROTECT FAIL:'+str(rank)+':resp:'+str(ret))
        #     gpio.digital_write(bsl, 0)    # reset bsl
        #     gpio.digital_write(disable, 1)    # enable second chip
        #     raise 'FLASHER:UNPROTECT FAIL:'+str(rank)+':erreur initialisation','NACK'
        # else
        #     self.mqttprint('FLASHER:UNPROTECT ACK 1:')
        #     ret=self.wait_ack(10)
        #     while str(ret).size() == 0 
        #         ret=self.wait_ack(10)
        #     end
        # end

        self.ser.write(0x7F)
        ret = self.wait_ack(50)
        self.mqttprint('FLASHER:SET BOOT MODE 2:'+str(rank)+':ret='+str(ret))
        if str(ret) != '79'
            self.mqttprint('FLASHER:SET BOOT MODE 2:'+str(rank)+':resp:'+str(ret))
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:SET BOOT MODE 2:'+str(rank)+':erreur initialisation','NACK'
        end
    end
    #------------------------------------------------------------------------------------#
    #                                   GETINFO                                          #
    #------------------------------------------------------------------------------------#
    def getinfo(stm32) 
        var bsl
        var disable
        var ret
        if stm32=='in'
            bsl=self.bsl_in
            disable=self.rst_out
        else
            bsl=self.bsl_out
            disable=self.rst_in
        end    

        self.ser.write(bytes('01FE'))
        ret = self.wait_ack(50)     # malek
        if str(ret) != '79'
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:INFO:erreur envoi 1','NACK'
        else
            self.mqttprint('FLASHER:INFO:Protocol version -> '+str(ret))
        end

        self.ser.write(bytes('02FD'))
        ret = self.wait_ack(50)     # malek
        if str(ret) != '79'
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:INFO:erreur envoi 1','NACK'
        else
            self.mqttprint('FLASHER:INFO:Chip ID -> '+ret[4]+ret[5]+ret[6]+ret[7])
        end
    end
 
    #------------------------------------------------------------------------------------#
    #                                   UNPROTTECT                                       #
    #------------------------------------------------------------------------------------#
    def unprotect(stm32) 
        var readbytes
        var disable
        var rst
        var ret
        if stm32=='in'
            rst=self.rst_in
            disable=self.rst_out
        else
            rst=self.rst_out
            disable=self.rst_in
        end    

        self.ser.write(bytes('738C'))
        ret = self.wait_ack(50)     # malek
        gpio.digital_write(rst, 0)  
        tasmota.delay(1) 
        gpio.digital_write(rst, 1)    # enable second chip
        tasmota.delay(1)  
    end
 
    def terminate(stm32)
        var rst
        var bsl
        var disable
        gpio.pin_mode(self.rst_in,gpio.OUTPUT)
        gpio.pin_mode(self.bsl_in,gpio.OUTPUT)
        gpio.pin_mode(self.rst_out,gpio.OUTPUT)
        gpio.pin_mode(self.bsl_out,gpio.OUTPUT)
       if stm32=='in'
            rst=self.rst_in
            bsl=self.bsl_in
            disable=self.rst_out
         else
            rst=self.rst_out
            bsl=self.bsl_out
            disable=self.rst_in
         end
       
        self.mqttprint('FLASHER:TERMINATE:reset')
        gpio.digital_write(disable, 1)    # enable second chip
        tasmota.delay(10)
        gpio.digital_write(bsl, 0)    # reset bsl
        tasmota.delay(10)
        gpio.digital_write(rst, 0)    # trigger Reset
        tasmota.delay(10)
        gpio.digital_write(rst, 1)    # trigger Reset
    end

   #------------------------------------------------------------------------------------#
    #                                   CONVERSION FICHIER                               #
    #------------------------------------------------------------------------------------#
    def write_block(fichier,addresse,token)
        import string
        var ret
        var payload1,payload2,payload3
        var message
        var mycrc = 0
        var bAddresse
   
        bAddresse = bytes(string.format('%08X',addresse))
        mycrc = 0
        mycrc ^= bAddresse[0]
        mycrc ^= bAddresse[1]
        mycrc ^= bAddresse[2]
        mycrc ^= bAddresse[3]
        payload2 =bAddresse + bytes(string.format('%02X',mycrc))
        fichier.write(payload2)
  
        mycrc = 0
        for i: 1..size(token)
          mycrc ^= token[i-1]
        end
        mycrc ^= 0xFF
        mycrc ^= size(token)
        payload3 = bytes(string.format('%02s%sFF%02X',string.hex(size(token)),token.tohex(),mycrc))
        fichier.write(payload3)
    end

    def convert(filename)
        var tas = tasmota
        var yield = tasmota.yield
        var file_convname 
        var file_conv
        var file
        var BLOCK = 252
        var numB, reste
        var token
        if type(filename) != 'string'   raise "erreur", "nom fichier non valide" end
        file_convname = filename+'c'
        file_conv = open(file_convname, "wb")    
        file = open(filename,"rb")
        numB = file.size()/BLOCK
        reste = file.size() - numB*BLOCK
        try
            for i: 1 .. numB
                token = file.readbytes(BLOCK)
                self.write_block(file_conv,0x08000000+((i-1)*BLOCK),token)
                yield(tas)        # tasmota.yield() -- faster version
            end
            token = file.readbytes(reste)
            self.write_block(file_conv,0x08000000+(numB*BLOCK),token)
        except .. as e, m
            file.close()
            raise e, m      # re-raise
        end
        file.close()
        file_conv.close()
        self.mqttprint('FLASHER:CONVERT:conversion done')
    end

    #------------------------------------------------------------------------------------#
    #                                   ECRITURE FICHIER                                 #
    #------------------------------------------------------------------------------------#
    def flash(filename,stm32)
        var bsl
        var disable
        var tas = tasmota
        var yield = tasmota.yield
        var cfile = filename+'c'
        var file
        var index = 0
        var token
        var BLOCK = 252
        var ret
        if stm32=='in'
            bsl=self.bsl_in
            disable=self.rst_out
         else
            bsl=self.bsl_out
            disable=self.rst_in
         end

         self.init()
        
        #  self.initialisation_stm32(1,stm32)
        #  self.unprotect(stm32)
        #  self.initialisation_stm32(2,stm32)
        #  self.getinfo(stm32)
         self.initialisation_stm32(1,stm32)
        #  print('FLASHER:FLASH:unprotect memory')
        #  self.ser.write(bytes('738C'))
        #  ret = self.wait_ack(100)     # malek
        #  print('FLASHER:FLASH:unprotect->'+str(ret))
        #  self.ser.flush()
         file = open(cfile,"rb")
        while index < file.size()
            self.ser.write(bytes('31CE'))
            ret = self.wait_ack(50)     # malek
            if str(ret) != '79'
              self.mqttprint('FLASHER:FLASH:resp:'+str(index)+':'+str(ret))
              gpio.digital_write(bsl, 0)    # reset bsl
              gpio.digital_write(disable, 1)    # enable second chip
              raise 'FLASHER:FLASH:erreur envoi 1','NACK'
            end
              
            token = file.readbytes(5)
            self.ser.write(token)
            ret = self.wait_ack(50)
            if str(ret) != '79'
                self.mqttprint('FLASHER:FLASH:resp:'+str(ret))
                gpio.digital_write(bsl, 0)    # reset bsl
                gpio.digital_write(disable, 1)    # enable second chip
                raise 'FLASHER:FLASH:erreur envoi 2','NACK'
            end   
            index += size(token)

            token = file.readbytes(BLOCK+3)
            self.ser.write(token)
            ret = self.wait_ack(50)
            if str(ret) != '79'
                self.mqttprint('FLASHER:FLASH:resp:'+str(ret))
                gpio.digital_write(bsl, 0)    # reset bsl
                gpio.digital_write(disable, 1)    # enable second chip
                raise 'FLASHER:FLASH:erreur envoi 3','NACK'
            end   
            index += size(token)
            yield(tas)        # tasmota.yield() -- faster version
        end
        file.close()
        self.mqttprint('FLASHER:FLASH:dernier token:'+str(size(token)))
        self.mqttprint('FLASHER:FLASH:index:'+str(index))
        self.terminate(stm32)
        self.mqttprint('FLASHER:FLASH:flashing done')
    end

    #------------------------------------------------------------------------------------#
    #                                   EFFACEMENT                                       #
    #------------------------------------------------------------------------------------#
    def erase(stm32)
        var rst
        var bsl
        var ret
        var disable
        if stm32=='in'
            rst=self.rst_in
            bsl=self.bsl_in
            disable=self.rst_out
         else
            rst=self.rst_out
            bsl=self.bsl_out
            disable=self.rst_in
         end

        self.init()
        self.initialisation_stm32(1,stm32)
        self.mqttprint('FLASHER:ERASE:initialisation hardware')
        # start erase
         self.ser.write(bytes('44BB'))
         ret = self.wait_ack(50) 
         if str(ret) != '79'
            self.mqttprint('FLASHER:ERASE:resp:'+str(ret))
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:ERASE:erreur erase 1','NACK'
        end   
         self.mqttprint("FLASHER:ERASE:start:"+str(ret))
         self.ser.write(bytes('FFFF00'))
         tasmota.delay(20000)
        ret = self.wait_ack(50) 
         if str(ret) != '79'
            self.mqttprint('FLASHER:ERASE:resp:'+str(ret))
            gpio.digital_write(bsl, 0)    # reset bsl
            gpio.digital_write(disable, 1)    # enable second chip
            raise 'FLASHER:ERASE:erreur erase 2','NACK'
        end   
        self.mqttprint("FLASHER:ERASE:end:"+str(ret))
        self.terminate(stm32)
    end

end
return dualflasher()