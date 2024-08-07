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
    var argument = string.split(string.toupper(payload)," ")
    if(argument[0]!="VA" && argument[0]!="VB" && argument[0] !="VC" && argument[0] != "IA" && argument[0] != "IB" && argument[0] != "IC" && argument[0] != "IN" 
        || argument[1] == "")
        print("erreur arguments")
        return
    end
    var token
    if(argument[0] =="VA" || argument[0] =="VB" || argument[0] =="VC")
        token = string.format("CAL %s %s",argument[0],argument[1])
    else
        token = string.format("CAL %s %s %s",argument[0],argument[1],argument[2])
    end
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring(token))
    print(token)
    tasmota.resp_cmnd_done()
end

def SerialSetup(cmd, idx, payload, payload_json)
    var argument = string.split(payload," ")
    if(argument[0]!="A" && argument[0]!="B" && argument[0] !="C" && argument[0] != "N" && argument[0] != "OI" && argument[0] != "OV" && argument[0] != "KI" && argument[0] != "KV" && argument[0] != "ROOT" && argument[0] != "RATIO" 
        && argument[0] != "LOGTYPE" && argument[0] != "LOGFREQN" || argument[1] == "" || argument[1] == "")
        print("erreur arguments")
        return
    end
    var token
    if(argument[0]=="A" || argument[0]=="B" || argument[0] =="C" || argument[0] == "N")
        if(argument[0]=="N")
            token = string.format("SET Neutral %s",argument[1])
        else
            token = string.format("SET Phase_%s %s",argument[0],argument[1])
        end
    elif(argument[0]=="CAL")
        Calibration(argument[1],argument[2],argument[3])
        return
    else
        token = string.format("SET %s %s",argument[0],argument[1])
    end
    # initialise UART Rx = GPIO3 and TX=GPIO1
    # send data to serial
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring(token))
    tasmota.resp_cmnd_done()
    print("SET:",token)
end

def Init()
    gpio.pin_mode(rx,gpio.INPUT)
    gpio.pin_mode(tx,gpio.OUTPUT)
    ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    print("serial initialised")
    tasmota.resp_cmnd_done()
end

def readcal()
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring("CAL READ"))
    print('CAL READ')
    tasmota.resp_cmnd_done()
end

def storecal()
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring("CAL STORE"))
    print('CAL STORE')
    tasmota.resp_cmnd_done()
end

def BlReset(cmd, idx, payload, payload_json)
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    ser.write(bytes().fromstring("SET RESET"))
    print("SET RESET")
    tasmota.resp_cmnd_done()
end

def BlMode(cmd, idx, payload, payload_json)
    var argument = string.split(string.toupper(payload)," ")
    if(argument[0]!="CAL" && argument[0] !="LOG" )
        print("erreur arguments")
        return
    end
    # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
    ser.flush()
    if(argument[0]=="CAL")
        ser.write(bytes().fromstring("SET MODE CAL"))
        print("SET MODE CAL")
    else
        ser.write(bytes().fromstring("SET MODE LOG"))
        print("SET MODE LOG")
    end
    tasmota.resp_cmnd_done()
end

def Stm32Reset()
        gpio.pin_mode(rst,gpio.OUTPUT)
        gpio.pin_mode(bsl,gpio.OUTPUT)
  
        gpio.digital_write(rst, 0)
        tasmota.delay(100)               # wait 10ms
        gpio.digital_write(rst, 1)
        tasmota.delay(100)               # wait 10ms
        tasmota.resp_cmnd("STM32 IN reset")
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
    tasmota.resp_cmnd("done")
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
    tasmota.resp_cmnd("done")
end

def getfile(cmd, idx,payload, payload_json)
    import string
    var path = "https://raw.githubusercontent.com//mbenfe/upload/main/"
    path+=payload
    print(path)
    var file=string.split(path,"/").pop()
    print(file)
    var wc=webclient()
    wc.set_follow_redirects(true)
    wc.begin(path)
    var st=wc.GET()
    if st!=200 
        raise "erreur","code: "+str(st) 
    end
    st="Fetched "+str(wc.write_file(file))
    print(path,st)
    wc.close()
    var message = "uploaded:"+file
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
    var total = "";
    # var ser
    var header
    var trouve = false
    print("send:",payload)
    ############################ fichier config ###################
    file = open("esp32.cfg","rt")
    buffer = file.read()
    myjson=json.load(buffer)
    device = myjson["device"]
    file.close()

    file = open(payload,"rt")
    if file == nil
        print("fichier non existant:",payload)
        return
    end
    buffer = file.read()
    file.close()
    myjson = json.load(buffer)
    for key:myjson.keys()
        if key == device
            trouve = true
          total+="CONFIG"+" "+key+"_"
                    +myjson[key]["root"][0]+"_"+myjson[key]["root"][1]+"_"+myjson[key]["root"][2]+"_"+myjson[key]["root"][3]+"_"
                    +myjson[key]["produit"]+"_"
                    +myjson[key]["techno"][0]+"_"+myjson[key]["techno"][1]+"_"+myjson[key]["techno"][2]+"_"+myjson[key]["techno"][3]+"_"
                    +myjson[key]["ratio"][0]+"_"+myjson[key]["ratio"][1]+"_"+myjson[key]["ratio"][2]+"_"+myjson[key]["ratio"][3]
        end
    end
    if trouve == true
        # ser = serial(rx,tx,115200,serial.SERIAL_8N1)
        ser.flush()
        var mybytes=bytes().fromstring(total)
        ser.write(mybytes)
        print(total)
        tasmota.resp_cmnd("config sent")
    else
        print("device ",device," non touvé")
        tasmota.resp_cmnd("config not sent")
    end
end

def launch_driver()
    print("mqtt connected -> launch driver")
    tasmota.load("stm32_driver.be")
 end

 def help()
    print("Stm32reset:reset du STM32")
    print("getfile <path/filename>: load file")
    print("sendconfig p_<name>.json: configure pwx")
    print("ville <nom>: set ville")
    print("device <nom>: set device name")
    print("SerialSetup",SerialSetup)
    print("BlReset: reset the BL6552 chip")
    print("BlMode <mode> (cal ou log): set mode ")
    print("Init",Init)
    print("cal <parameter> <value> (VA, VB ou VC)")
    print("ex: cal VA 235")
    print("cal <device> <parameter> <value> (IA, IB ou IC)")
    print("ex: cal IA 1 5.1")
    print("readcal: affiche les parametres de calibration")
    print("storecal: sauvegarde la calibration")
    print("h: this help")
 end

tasmota.cmd("seriallog 0")
print("serial log disabled")

tasmota.add_cmd("Stm32reset",Stm32Reset)
tasmota.add_cmd("getfile",getfile)
tasmota.add_cmd("sendconfig",sendconfig)
tasmota.add_cmd("ville",ville)
tasmota.add_cmd("device",device)
tasmota.add_cmd("SerialSetup",SerialSetup)
tasmota.add_cmd("BlReset",BlReset)
tasmota.add_cmd("BlMode",BlMode)
tasmota.add_cmd("Init",Init)
tasmota.add_cmd("cal",Calibration)
tasmota.add_cmd("readcal",readcal)
tasmota.add_cmd("storecal",storecal)
tasmota.add_cmd("h",help)

############################################################
tasmota.load("pwx12_driver.be")
tasmota.delay(500)
tasmota.cmd("Init")
tasmota.cmd("Teleperiod 0")


