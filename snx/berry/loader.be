
class loader
    def upload(payload)
        import string
        var path = 'https://github.com/mbenfe/upload/raw/main/'
        path+=payload
        path = 'https://raw.githubusercontent.com/arendst/Tasmota/development/tasmota/zigbee/giex_water.zb'
        print(path)
        var file=string.split(path,'/').pop()
        print(file)
        var wc=webclient()
        wc.begin(path)
        var st=wc.GET()
        if st!=200 
            raise 'connection_error','status: '+str(st) 
        end
        st='Fetched '+str(wc.write_file(file))
        print(path,st)
        wc.close()
        return st
    end
end
return loader()