#---------------------------------#
# VERSION 1.0 PWX 12              #
#---------------------------------#
import string
import global
import mqtt
import json
import gpio

var ser                # serial object

var rx=16    
var tx=17    
var rst=2   
var bsl=13   


#-------------------------------- COMMANDES -----------------------------------------#
def Calibration(cmd, idx, payload, payload_json)
    var argument = string.split(string.toupper(payload),' ')
    if(argument[0]!='VA' && argument[0]!='VB' && argument[0] !='VC' && argument[0] != 'IA' && argument[0] != 'IB' && argument[0] != 'IC' && argument[0] != 'IN' 
        || argument[1] == '')
        print('erreur arguments')
        return
    end
    var token
    if(argument[0] =='VA' || argument[0] =='VB' || argument[0] =='VC')
        token = string.format('CAL %s %s',argument[0],argument[1])
    else
        token = string.format('CAL %s %s %s',argument[0],argument[1],argument[2])
    end
    gpio.pin_mode(rx,gpio.INPUT)
    gpio.pin_mode(tx,gpio.OUTPUT)
    ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring(token))
    ser.write(bytes().fromstring(token))
    print(token)
    tasmota.resp_cmnd_done()
end

def SerialSetup(cmd, idx, payload, payload_json)
    var argument = string.split(payload,' ')
    if(argument[0]!='A' && argument[0]!='B' && argument[0] !='C' && argument[0] != 'N' && argument[0] != 'OI' && argument[0] != 'OV' && argument[0] != 'KI' && argument[0] != 'KV' && argument[0] != 'ROOT' && argument[0] != 'RATIO' 
        && argument[0] != 'LOGTYPE' && argument[0] != 'LOGFREQN' || argument[1] == '' || argument[1] == '')
        print('erreur arguments')
        return
    end
    var token
    if(argument[0]=='A' || argument[0]=='B' || argument[0] =='C' || argument[0] == 'N')
        if(argument[0]=='N')
            token = string.format('SET Neutral %s',argument[1])
        else
            token = string.format('SET Phase_%s %s',argument[0],argument[1])
        end
    elif(argument[0]=='CAL')
        Calibration(argument[1],argument[2],argument[3])
        return
    else
        token = string.format('SET %s %s',argument[0],argument[1])
    end
    # initialise UART Rx = GPIO3 and TX=GPIO1
    # send data to serial
    ser.write(bytes().fromstring(token))
    tasmota.resp_cmnd_done()
    print('SET:',token)
end

def Init()
    gpio.pin_mode(rx,gpio.INPUT)
    gpio.pin_mode(tx,gpio.OUTPUT)
    ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    print('serial initialised')
    tasmota.resp_cmnd_done()
end

def RnReset(cmd, idx, payload, payload_json)
    ser.write(bytes().fromstring('SET RESET'))
    tasmota.delay(500)
    tasmota.resp_cmnd_done()
end

def RnMode(cmd, idx, payload, payload_json)
    var argument = string.split(payload,' ')
    if(argument[0]!='MONO' && argument[0] !='TRI' )
        print('erreur arguments')
        return
    end
    if(argument[0]=='MONO')
        ser.write(bytes().fromstring('SET MODE MONO'))
    else
        ser.write(bytes().fromstring('SET MODE TRI'))
    end
    tasmota.delay(500)
    tasmota.resp_cmnd_done()
end

def Stm32Reset()
        gpio.pin_mode(rst,gpio.OUTPUT)
        gpio.pin_mode(bsl,gpio.OUTPUT)
  
        gpio.digital_write(rst, 0)
        tasmota.delay(100)               # wait 10ms
        gpio.digital_write(rst, 1)
        tasmota.delay(100)               # wait 10ms
        tasmota.resp_cmnd('STM32 IN reset')
end

def ville(cmd, idx,payload, payload_json)
    import json
    var file = open("esp32.cfg","rt")
    var buffer = file.read()
    var myjson=json.load(buffer)
    myjson["ville"]=payload
    buffer = json.dump(myjson)
    file.close()
    file = open("esp32.cfg","wt")
    file.write(buffer)
    file.close()
    tasmota.resp_cmnd('done')
end

def device(cmd, idx,payload, payload_json)
    import json
    var file = open("esp32.cfg","rt")
    var buffer = file.read()
    var myjson=json.load(buffer)
    myjson["device"]=payload
    buffer = json.dump(myjson)
    file.close()
    file = open("esp32.cfg","wt")
    file.write(buffer)
    file.close()
    tasmota.resp_cmnd('done')
end

def getfile(cmd, idx,payload, payload_json)
    import string
    var path = 'https://raw.githubusercontent.com//mbenfe/upload/main/'
    path+=payload
    print(path)
    var file=string.split(path,'/').pop()
    print(file)
    var wc=webclient()
    wc.set_follow_redirects(true)
    wc.begin(path)
    var st=wc.GET()
    if st!=200 
        raise 'erreur','code: '+str(st) 
    end
    st='Fetched '+str(wc.write_file(file))
    print(path,st)
    wc.close()
    var message = 'uploaded:'+file
    tasmota.resp_cmnd(message)
    return st
end

def sendconfig(cmd, idx,payload, payload_json)
    import string
    import json
    var file
    var buffer
    var myjson
    var device
    var total = '';
    var ser
    var header
    var trouve = false
    print('send:',payload)
    ############################ fichier config ###################
    file = open("esp32.cfg","rt")
    buffer = file.read()
    myjson=json.load(buffer)
    device = myjson["device"]
    file.close()

    file = open(payload,"rt")
    if file == nil
        print('fichier non existant:',payload)
        return
    end
    buffer = file.read()
    file.close()
    myjson = json.load(buffer)
    for key:myjson.keys()
        if key == device
            trouve = true
          total+='CONFIG'+' '+key+'_'
                    +myjson[key]["root"][0]+'_'+myjson[key]["root"][1]+'_'+myjson[key]["root"][2]+'_'+myjson[key]["root"][3]+'_'
                    +myjson[key]["produit"]+'_'
                    +myjson[key]["techno"][0]+'_'+myjson[key]["techno"][1]+'_'+myjson[key]["techno"][2]+'_'+myjson[key]["techno"][3]+'_'
                    +myjson[key]["ratio"][0]+'_'+myjson[key]["ratio"][1]+'_'+myjson[key]["ratio"][2]+'_'+myjson[key]["ratio"][3]
        end
    end
    if trouve == true
        ser = serial(rx,tx,115200,serial.SERIAL_8N1)
        ser.flush()
        var mybytes=bytes().fromstring(total)
        ser.write(mybytes)
        print(total)
        tasmota.resp_cmnd("config sent")
    else
        print('device ',device,' non touvé')
        tasmota.resp_cmnd("config not sent")
    end
end

def launch_driver()
    print('mqtt connected -> launch driver')
    tasmota.load('stm32_driver.be')
 end

tasmota.cmd("seriallog 0")
print("serial log disabled")

print('AUTOEXEC: create commande Stm32Reset')
tasmota.add_cmd('Stm32reset',Stm32Reset)

print('AUTOEXEC: create commande getfile')
tasmota.add_cmd('getfile',getfile)

print('AUTOEXEC: create commande sendconfig')
tasmota.add_cmd('sendconfig',sendconfig)

tasmota.add_cmd('ville',ville)
tasmota.add_cmd('device',device)
tasmota.add_cmd('SerialSetup',SerialSetup)
tasmota.add_cmd('RnReset',RnReset)
tasmota.add_cmd('RnMode',RnMode)
tasmota.add_cmd('Init',Init)
tasmota.add_cmd('cal',Calibration)

############################################################
tasmota.load('pwx12_driver.be')
tasmota.delay(500)
tasmota.cmd('Init')
tasmota.cmd('Teleperiod 0')


