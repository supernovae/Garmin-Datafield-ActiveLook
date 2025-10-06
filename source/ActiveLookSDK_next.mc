using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.System;

using ActiveLookBLE;
using ActiveLook.PageSettings;
using ActiveLook.Layouts;

(:typecheck(false))
module ActiveLookSDK {

    //! Private logger enabled in debug and disabled in release mode
    (:release) function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {}
    (:debug)   function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {
        //if ($ has :log) { $.log(Toybox.Lang.format("[ActiveLookSDK] $1$", [msg]), data); }
    }

    //! Interface for listener
    typedef ActiveLookListener as interface {
        function onFirmwareEvent(major as Toybox.Lang.Number, minor as Toybox.Lang.Number, patch as Toybox.Lang.Number) as Void;
        function onCfgVersionEvent(cfgVersion as Toybox.Lang.Number) as Void;
        function onFreeSpaceEvent(freeSpace as Toybox.Lang.Number) as Void;
        function onGestureEvent() as Void;
        function onBatteryEvent(batteryLevel as Toybox.Lang.Number) as Void;
        function onNotEnoughBatteryEvent(batteryLevel as Toybox.Lang.Number) as Void;
        function onDeviceReady() as Void;
        function onDeviceDisconnected() as Void;
        function onBleError(exception as Toybox.Lang.Exception) as Void;
    };

    //! The status of the Active Look SDK is represented by a lot of flags.
    var isScanning                                   as Toybox.Lang.Boolean                      = false;
    var isPairing                                    as Toybox.Lang.Boolean                      = false;
    var isReconnecting                               as Toybox.Lang.Boolean                      = false;
    var isRegisteringProfile                         as Toybox.Lang.Boolean                      = false;

    var layoutCmdId                                  as Lang.Number                              = 0x66;

    var device                                       as Toybox.BluetoothLowEnergy.Device or Null = null;
    function isConnected()                           as Toybox.Lang.Boolean {
        return device != null;
    }

    var userPages                                    as Toybox.Lang.Array                        = [];
    var glassesPageList                              as Toybox.Lang.Array                        = [];
    var glassesPageBuffer                            as Toybox.Lang.Array                        = [];

    var isActivatingGestureNotif                     as Toybox.Lang.Boolean                      = false;
    var isGestureNotifActivated                      as Toybox.Lang.Boolean                      = false;

    var isActivatingBatteryNotif                     as Toybox.Lang.Boolean                      = false;
    var isBatteryNotifActivated                      as Toybox.Lang.Boolean                      = false;

    var isActivatingALookTxNotif                     as Toybox.Lang.Boolean                      = false;
    var isALookTxNotifActivated                      as Toybox.Lang.Boolean                      = false;

    var isReadingBattery                             as Toybox.Lang.Boolean                      = false;
    var batteryLevel                                 as Toybox.Lang.Number or Null               = null;
    function isBatteryRead()                         as Toybox.Lang.Boolean {
        return batteryLevel != null;
    }

    var isReadingFirmwareVersion                     as Toybox.Lang.Boolean                      = false;
    var firmwareVersion                              as Toybox.Lang.String or Null               = null;
    function isFirmwareVersionRead()                 as Toybox.Lang.Boolean {
        return firmwareVersion != null;
    }

    var isReadingCfgVersion                          as Toybox.Lang.Boolean                      = false;
    var cfgVersion                                   as Toybox.Lang.Number or Null               = null;
    function isCfgVersionRead()                      as Toybox.Lang.Boolean {
        return cfgVersion != null;
    }
    
    var isReadingPageList                            as Toybox.Lang.Boolean                      = false;
    var isPageListRead                               as Toybox.Lang.Boolean                      = false;
    
    var isReadingPages                               as Toybox.Lang.Boolean                      = false;
    var isPagesRead                                  as Toybox.Lang.Boolean                      = false;

    // freeSpaceLimit is the minimum free space required to save a page, if freeSpace < freeSpaceLimit, less used configurations will be deleted
    var freeSpaceLimit                               as Toybox.Lang.Number                       = 400;
    var isReadingFreeSpace                           as Toybox.Lang.Boolean                      = false;
    var freeSpace                                    as Toybox.Lang.Number or Null               = null;
    var isFreeSpaceRead                              as Toybox.Lang.Boolean                      = false;

    var isDeletingLessUsedCfg                        as Toybox.Lang.Boolean                      = false;
    var isLessUsedCfgDeleted                         as Toybox.Lang.Boolean                      = false;

    var isSavingPage                               as Toybox.Lang.Boolean                        = false;
    var isPageSaved                                as Toybox.Lang.Boolean                        = false;
    
    var isUpdatingALSSensor                          as Toybox.Lang.Boolean                      = false;
    var isALSSensorUpdated                           as Toybox.Lang.Boolean                      = false;

    var isUpdatingGestureSensor                      as Toybox.Lang.Boolean                      = false;
    var isGestureSensorUpdated                       as Toybox.Lang.Boolean                      = false;

    var offsetIdPage                                 as Toybox.Lang.Number                       = 100;

    function isIdled()                               as Toybox.Lang.Boolean {
        if (isScanning)               { return false; }
        if (isPairing)                { return false; }
        if (isActivatingGestureNotif) { return false; }
        if (isActivatingBatteryNotif) { return false; }
        if (isActivatingALookTxNotif) { return false; }
        if (isReadingBattery)         { return false; }
        if (isReadingFirmwareVersion) { return false; }
        if (isUpdatingALSSensor)      { return false; }
        if (isUpdatingGestureSensor)  { return false; }
        if (isReadingCfgVersion)      { return false; }
        if (isReadingFreeSpace)       { return false; }
        if (isDeletingLessUsedCfg)    { return false; }
        if (isSavingPage)             { return false; }
        if (isRegisteringProfile)     { return true;  }
        return true;
    }

    function isReady()                               as Toybox.Lang.Boolean {
        if (!isIdled())               { return false; }
        if (!isConnected())           { return false; }
        if (!isBatteryRead())         { return false; }
        if (!isFirmwareVersionRead()) { return false; }
        if (!isALSSensorUpdated)      { return false; }
        if (!isCfgVersionRead())      { return false; }
        if (!isFreeSpaceRead)         { return false; }
        if (!isGestureSensorUpdated)  { return false; }
        if (!isGestureNotifActivated) { return false; }
        if (!isBatteryNotifActivated) { return false; }
        if (!isALookTxNotifActivated) { return false; }
        return true;
    }

    var time = null;    var clearError = null;
    var timeHError = null; var timeMError = null;
    var battery = null; var batteryError = null;
    var cmdStacking = null; var cmdMaxSize  = 0;
    var ble = null;     var listener = null;

    var _cbCharacteristicWrite   = null;

    var layouts = [];
    var rotate = 0;
    var isWritingCharacteristic = false as Toybox.Lang.Boolean;

    class ALSDK {

        (:release) private static function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {}
        (:debug)   private static function _log(msg as Toybox.Lang.String, data as Toybox.Lang.Object or Null) as Void {
            //if ($ has :log) { $.log(Toybox.Lang.format("[ActiveLookSDK::ALSDK] $1$", [msg]), data); }
        }

        function initialize(obj) {
            listener = obj != null ? obj : self;
            ble = ActiveLookBLE.ActiveLook.setUp(self);
            userPages =  self.getUsersPages();
        }

        function startGlassesScan() {
            _log("startGlassesScan", []);
            if (!isReconnecting && isIdled()) {
                if (!ActiveLookBLE.ActiveLook.fixScanState()) {
                    ActiveLookBLE.ActiveLook.requestScanning(true);
                }
            }
        }
        function stopGlassesScan() {
            _log("stopGlassesScan", []);
            if (!ActiveLookBLE.ActiveLook.fixScanState()) {
                ActiveLookBLE.ActiveLook.requestScanning(false);
            }
        }
        function connect(device) {
            _log("connect", [device]);
            if (ble.connect(device)) {
                isPairing = true;
                isReconnecting = true;
            }
        }
        function disconnect() {
            _log("disconnect", []);
            if (isReady()) {
                self.clearScreen();
            }
            isReconnecting = false;
            tearDownDevice();
            ble.disconnect();
        }
        function resyncGlasses() {
            _log("resyncGlasses", []);
            if (cmdStacking != null)  { self.sendRawCmd([]b); }
            if (clearError == true) {
                self.clearScreen();
            }
            if (clearError != true) {
                if (batteryError != null) { self.setBattery(batteryError); }
                if (timeMError != null) { self.setTime(timeHError, timeMError); }
            }
        }

        function getUsersPages(){
            var pagesSpec = [];
            try {
                var _ai = "screens";
                if (Toybox.Activity has :getProfileInfo) {
                    var profileInfo = Toybox.Activity.getProfileInfo();
                    if (profileInfo has :sport) {
                        switch (profileInfo.sport) {
                            case Toybox.Activity.SPORT_RUNNING: { _ai = "run";     break; }
                            case Toybox.Activity.SPORT_CYCLING: { _ai = "bike";    break; }
                            default:                            { _ai = "screens"; break; }
                        }
                    }
                }
                pagesSpec = PageSettings.strToPages(Application.Properties.getValue(_ai), "(1,12,2)(15,4,2)(10,18,22)(0)");
                _log("getUsersPages",[pagesSpec]);
                return pagesSpec;
            } catch (e) {
                pagesSpec = PageSettings.strToPages("(1,12,2)(15,4,2)(10,18,22)(0)", null);
                _log("getUsersPages",[e, pagesSpec]);
                return pagesSpec;
            }
        }

        function pageToBuffer(pageSpec as PageSettings.PageSpec){
            var buffer = []b;
            var currentLayouts = Layouts.pageToGenerator(pageSpec);
            for(var i = 0; i < currentLayouts.size(); i++) {
                var layoutToBuffer = layoutToBufferSavePage(currentLayouts[i][:id]);
                if(layoutToBuffer.size() > 0){ 
                    if(layoutToBuffer[0] != 0x00){ 
                        buffer.addAll(layoutToBuffer);
                    }
                }
            }
            _log("pageToBuffer",[buffer]);
            return buffer;
        }
       
        function layoutToBufferSavePage(layout) {
            return [((layout >> 24) & 0xFF),((layout >> 16) & 0xFF),((layout >> 8) & 0xFF),(layout & 0xFF)]b;
        }
        
        function profileRegistrationStart() {
            isRegisteringProfile = true;
        }

        function profileRegistrationComplete() {
            isRegisteringProfile = false;
        }

        //! convert a number to a byte array
		function numberToByteArray(value) {
			var result = new [0]b;
			do {
				result.add(value & 0xFF);
				value = value >> 8;
			} while(value > 0);
			return result.reverse();
		}

		//! convert a number to a byte array of fixed size
		//! Throw an exception if trying to convert a number
		//! on a too small byte array.
		function numberToFixedSizeByteArray(value, size) {
			var optResult = self.numberToByteArray(value);
			var minSize = optResult.size();
			if (minSize > size) {
				throw new Toybox.Lang.InvalidValueException("value is too big");
			} else if (minSize == size) {
				return optResult;
			} else {
				var nbZeros = size - minSize;
				var result = new [nbZeros]b;
				result.addAll(optResult);
				return result;
			}
		}

        function byteArrayToInt(byteArray as Toybox.Lang.ByteArray, littleEndian as Toybox.Lang.Boolean) as Toybox.Lang.Integer {
            if (byteArray == null || byteArray.size() == 0) {
                return 0;
            }

            var result = 0;
            var byteCount = byteArray.size();

            if (littleEndian) {
                // Little-endian (LSB first)
                for (var i = 0; i < byteCount; i++) {
                    result |= byteArray[i] << (8 * i);
                }
            } else {
                // Big-endian (MSB first)
                for (var i = 0; i < byteCount; i++) {
                    result |= byteArray[i] << (8 * (byteCount - 1 - i));
                }
            }

            return result;
        }

        function stringToPadByteArray(str, size, leftPadding) {
			var result = StringUtil.convertEncodedString(str, {
				:fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
				:toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
				:encoding => StringUtil.CHAR_ENCODING_UTF8
			});
			if(size) {
				var padSize = size - result.size();
				if(padSize > 0) {
					var padBuffer = []b;
					do {
						padBuffer.add(0x20);
						padSize -= 1;
					} while(padSize > 0);
					if(leftPadding) {
						padBuffer.addAll(result);
						result = padBuffer;
					} else {
						result.addAll(padBuffer);
					}
				}
			}
			result.add(0x00);
			return result;
		}

		function commandBuffer(id, data) {
			var buffer = new[0]b;
            var size = 5 + data.size();
            cmdMaxSize = cmdMaxSize < size ? size : cmdMaxSize;
			buffer.addAll([0xFF, id, 0x00, 0x05 + data.size()]b);
			buffer.addAll(data);
			buffer.add(0xAA);
            _log("buffer",[buffer]);
			return buffer;
		}

        //////////////
        // Commands //
        //////////////
        function setBattery(arg) {
            batteryError = null;
            if (arg != battery) {
                try {
                    var data = [0x07]b;
                    var paddingChar = arg < 10 ? "$" :  "";
                    data.addAll(self.stringToPadByteArray(paddingChar + arg.toString(), 3, true));
                    _log("setBattery",[data]);
                    self.sendRawCmd(self.commandBuffer(0x62, data));
                    battery = arg;
                } catch (e) {
                    batteryError = arg;
                    onBleError(e);
                }
            }
        }

        function cfgRead() {
            try {
                var data = [0x41, 0x4C, 0x6F, 0x6F, 0x4B]b; // ALooK
                self.sendRawCmd(self.commandBuffer(0xD1, data));
            } catch (e) {
                isReadingCfgVersion = false;
                cfgVersion = null;
                onBleError(e);
            }
        }

        function pageList() {
            try {
                self.sendRawCmd(self.commandBuffer(0x85, []b));
            } catch (e) {
                isReadingPageList = false;
                onBleError(e);
            }
        }

        function pageGet(id) {
            try {
                var data = numberToByteArray(id);
                self.sendRawCmd(self.commandBuffer(0x81, data));
            } catch (e) {
                isReadingPages = false;
                onBleError(e);
            }
        }

        function freeSpaceRead() {
            try {
                _log("freeSpaceRead",[]);
                self.sendRawCmd(self.commandBuffer(0xD7, []b));
            } catch (e) {
                isReadingFreeSpace = false;
                onBleError(e);
            }
        }
        
        function cfgDeleteLessUsed() {
            try {
                _log("cfgDeleteLessUsed",[]);
                self.sendRawCmd(self.commandBuffer(0xD6, []b));
            } catch (e) {
                isDeletingLessUsedCfg = false;
                onBleError(e);
            }
        }

        function setTime(hour, minute) {
            timeHError = null;
            timeMError = null;
            if (time != minute) {
                try {
                    time = minute;
                    var value = hour.format("%02d") + ":" + minute.format("%02d");
                    var data = [0x0A]b;
                    data.addAll(self.stringToPadByteArray(value, null, null));
                    _log("setTime", [data]);
                    self.sendRawCmd(self.commandBuffer(0x62, data));
                } catch (e) {
                    time = null;
                    timeHError = hour;
                    timeMError = minute;
                    onBleError(e);
                }
            }
        }

        function clearScreen() {
            clearError = null;
            try {
                _log("clearScreen", [1]);
                self.sendRawCmd(self.commandBuffer(0x01, []b));
                time = null;
                if (batteryError == null) {
                    batteryError = battery;
                }
                battery = null;
                self.resetLayouts([]);
                self.resyncGlasses();
            } catch (e) {
                clearError = true;
                onBleError(e);
            }
        }

        function Text(text, x, y, rotation, size, color) {
			var data = []b;
			data.addAll(self.numberToFixedSizeByteArray(x, 2));
			data.addAll(self.numberToFixedSizeByteArray(y, 2));
			data.addAll([rotation, size, color]b);
			data.addAll(self.stringToPadByteArray(text, null, null));
            self.sendRawCmd(self.commandBuffer(0x37, data));
		}


        function __onWrite_finishPayload(c, s) {
            _cbCharacteristicWrite = null;
            if (s == 0) {
                self.sendRawCmd([]b);
            } else {
                throw new Toybox.Lang.InvalidValueException("(E) Could write on: " + c);
            }
        }

        function sendRawCmd(buffer) {
            var bufferToSend = []b;
            flushCmdStackingIfSup(200);
            if (cmdStacking != null) {
                bufferToSend.addAll(cmdStacking);
                cmdStacking = null;
            }
            bufferToSend.addAll(buffer);
            _log("sendRawCmdBufferSize", [bufferToSend.size(), isWritingCharacteristic]);
            if(isWritingCharacteristic){
                cmdStacking = bufferToSend;
                return;
            }
            try {
                if (bufferToSend.size() > 20) {
                    var sendNow = bufferToSend.slice(0, 20);
                    cmdStacking = bufferToSend.slice(20, null);
                    _cbCharacteristicWrite = self.method(:__onWrite_finishPayload);
                    ble.getBleCharacteristicActiveLookRx()
                        .requestWrite(sendNow, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
                    _log("cmdSended",[arrayToHex(sendNow)]);
                    isWritingCharacteristic = true;
                } else if (bufferToSend.size() > 0) {
                    ble.getBleCharacteristicActiveLookRx()
                        .requestWrite(bufferToSend, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
                    _log("cmdSended",[arrayToHex(bufferToSend)]);
                    isWritingCharacteristic = true;
                }
            } catch (e) {
                cmdStacking = bufferToSend;
                onBleError(e);
            }
		}

        function flushCmdStacking(){
            _log("flushCmdStacking",["Size : "+ cmdStacking.size()]);
            var dummyBits = self.dummyBits(cmdMaxSize) as Toybox.Lang.ByteArray;
            cmdStacking = dummyBits.size() != 0 ? dummyBits : null ;
            cmdMaxSize = 0;
        }

        function flushCmdStackingIfSup(value as Toybox.Lang.Number){
            if(cmdStacking != null){
                if(cmdStacking.size() > value){
                    _log("flushCmdStackingIfSup",[value,cmdStacking == null ? 0 : cmdStacking.size()]);
                    flushCmdStacking();
                }
            }
        }

        function dummyBits(value){
            var data = []b;
            for (var i = 0; i < value; i++) {
                data.add(0x00);
            }
            return data;
        }

        function resetLayouts(args) {
            layouts = args;
            time = null;
            battery = null;
        }

        function __onWrite_finishpUdateLayoutValueBuffer(c, s) {
            _cbCharacteristicWrite = null;
            if (s == 0) {
                self.resyncGlasses();
            } else {
                _log("repair connection", []);
                isReconnecting = false;
                tearDownDevice();
                ble.disconnect();
                ActiveLookSDK.device = null;
                listener.onDeviceDisconnected();
            }
        }

        function setUpNewDevice(device as Toybox.BluetoothLowEnergy.Device) as Toybox.Lang.Boolean {
            _log("setUpNewDevice", [ActiveLookSDK.device, device]);
            if (ActiveLookSDK.device != null) {
                if (ActiveLookSDK.device != device) {
                    onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Device differs $1$ $2$.", [ActiveLookSDK.device, device])));
                    return false;
                }
            } else { ActiveLookSDK.device = device; }
            return setUpDevice();
        }

        function setUpDevice() as Toybox.Lang.Boolean {
            _log("setUpDevice", [ActiveLookSDK.device]);
            if (!isIdled()) { _log("setUpDevice", [ActiveLookSDK.device, "Not idle"]);
                return false;
            }
            if (!isConnected()) { _log("setUpDevice", [ActiveLookSDK.device, "Not connected"]);
                return false;
            }
            if (!isFirmwareVersionRead()) { _log("setUpDevice", [ActiveLookSDK.device, "Not isFirmwareVersionRead"]);
                if (!isReadingFirmwareVersion) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingFirmwareVersion"]);
                    try {
                        ble.getBleCharacteristicFirmwareVersion().requestRead();
                        isReadingFirmwareVersion = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isBatteryRead()) { _log("setUpDevice", [ActiveLookSDK.device, "Not isBatteryRead"]);
                if (!isReadingBattery) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingBattery"]);
                    try {
                        ble.getBleCharacteristicBatteryLevel().requestRead();
                        isReadingBattery = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isBatteryNotifActivated) { _log("setUpDevice", [ActiveLookSDK.device, "Not isBatteryNotifActivated"]);
                if (!isActivatingBatteryNotif) { _log("setUpDevice", [ActiveLookSDK.device, "Not isActivatingBatteryNotif"]);
                    try {
                        ble.getBleCharacteristicBatteryLevel().getDescriptor(BluetoothLowEnergy.cccdUuid()).requestWrite([0x01, 0x00]b);
                        isActivatingBatteryNotif = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isALookTxNotifActivated) { _log("setUpDevice", [ActiveLookSDK.device, "Not isALookTxNotifActivated"]);
                if (!isActivatingALookTxNotif) { _log("setUpDevice", [ActiveLookSDK.device, "Not isActivatingALookTxNotif"]);
                    try {
                        ble.getBleCharacteristicActiveLookTx().getDescriptor(BluetoothLowEnergy.cccdUuid()).requestWrite([0x01, 0x00]b);
                        isActivatingALookTxNotif = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isALSSensorUpdated) { _log("setUpDevice", [ActiveLookSDK.device, "Not isALSSensorUpdated"]);
                if (!isUpdatingALSSensor) { _log("setUpDevice", [ActiveLookSDK.device, "Not isUpdatingALSSensor"]);
                    try {    
                        var is_als_enable = Toybox.Application.Properties.getValue("is_als_enable") as Toybox.Lang.Boolean;
                        _log("is_als_enable",[is_als_enable]);
                        var data = []b;
                        if(is_als_enable){data = [0x01]b;}else{data = [0x00]b;}
                        ble.getBleCharacteristicActiveLookRx()
                            .requestWrite(self.commandBuffer(0x22, data), {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
                        isUpdatingALSSensor = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isPageListRead) { _log("setUpDevice", [ActiveLookSDK.device, "Not isPageListRead"]);
                if (!isReadingPageList) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingPageList"]);
                    try {
                        self.pageList();
                        isReadingPageList = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isPagesRead) { _log("setUpDevice", [ActiveLookSDK.device, "Not isPagesRead"]);
                if (!isReadingPages) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingPages"]);
                    try {
                        if(glassesPageList.size() == 0){
                            isReadingPages = false;
                            isPagesRead = true;
                        }else{
                            for(var i = 0; i < glassesPageList.size(); i++){
                                self.pageGet(glassesPageList[i]);
                            }
                            isReadingPages = true;
                        }
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isCfgVersionRead()) { _log("setUpDevice", [ActiveLookSDK.device, "Not isCfgVersionRead"]);
                if (!isReadingCfgVersion) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingCfgVersion"]);
                    try {
                        self.cfgRead();
                        isReadingCfgVersion = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            // TODO: Refacto no need to read free space if we don't need to save a page
            if (!isFreeSpaceRead) { _log("setUpDevice", [ActiveLookSDK.device, "Not isFreeSpaceRead"]);
                if (!isReadingFreeSpace) { _log("setUpDevice", [ActiveLookSDK.device, "Not isReadingFreeSpace"]);
                    try {
                        self.freeSpaceRead();
                        isReadingFreeSpace = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            } 
            // TODO: Refacto no need to delete less used cfg if we don't need to save a page
            if (!isLessUsedCfgDeleted) { _log("setUpDevice", [ActiveLookSDK.device, "Not isLessUsedCfgDeleted"]);
                if (!isDeletingLessUsedCfg) { _log("setUpDevice", [ActiveLookSDK.device, "Not isDeletingLessUsedCfg"]);
                    try {
                        self.cfgDeleteLessUsed();
                        isDeletingLessUsedCfg = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isPageSaved) { _log("setUpDevice", [ActiveLookSDK.device, "Not isPageSaved"]);
                if (!isSavingPage) { _log("setUpDevice", [ActiveLookSDK.device, "Not isSavingPage"]);
                    try {
                        var didSavedAPage = false;
                        for(var i = 0; i < userPages.size(); i++){
                            var pageBuffer = self.pageToBuffer(userPages[i]);
                            var buffer = numberToByteArray(i + offsetIdPage);
                            buffer.addAll(pageBuffer);
                            if(glassesPageBuffer.indexOf(buffer) == -1 && pageBuffer.size() > 0){
                                if(batteryLevel < 5){
                                    listener.onNotEnoughBatteryEvent(batteryLevel);
                                }else{
                                    if(!didSavedAPage){self.cfgWrite();}
                                    self.pageSave(buffer);
                                    isSavingPage = true;
                                }
                                didSavedAPage = true;
                            }
                        }
                        if(!didSavedAPage){
                            isPageSaved = true;
                            isSavingPage = false;
                        }
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isGestureSensorUpdated) { _log("setUpDevice", [ActiveLookSDK.device, "Not isGestureSensorUpdated"]);
                if (!isUpdatingGestureSensor) { _log("setUpDevice", [ActiveLookSDK.device, "Not isUpdatingGestureSensor"]);
                    try {        
                        var is_gesture_enable = Toybox.Application.Properties.getValue("is_gesture_enable") as Toybox.Lang.Boolean;
                        _log("is_gesture_enable",[is_gesture_enable]);
                        var data = []b;
                        if(is_gesture_enable){data = [0x01]b;}else{data = [0x00]b;}
                        ble.getBleCharacteristicActiveLookRx()
                            .requestWrite(self.commandBuffer(0x21, data), {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
                        isUpdatingGestureSensor = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            if (!isGestureNotifActivated) { _log("setUpDevice", [ActiveLookSDK.device, "Not isGestureNotifActivated"]);
                if (!isActivatingGestureNotif) { _log("setUpDevice", [ActiveLookSDK.device, "Not isActivatingGestureNotif"]);
                    try {
                        ble.getBleCharacteristicActiveLookGesture().getDescriptor(BluetoothLowEnergy.cccdUuid()).requestWrite([0x01, 0x00]b);
                        isActivatingGestureNotif = true;
                    } catch (e) { onBleError(e); }
                }
                return false;
            }
            listener.onDeviceReady();
            return true;
        }

        function tearDownDevice() as Void {
            _log("tearDownDevice", [ActiveLookSDK.device]);
            time = null;
            cmdStacking = null;
            cmdMaxSize = 0;
            freeSpace = null;
            glassesPageList = [];
            glassesPageBuffer = [];
            ActiveLookSDK.isScanning               = false;
            ActiveLookSDK.isPairing                = false;
            ActiveLookSDK.isActivatingGestureNotif = false;
            ActiveLookSDK.isGestureNotifActivated  = false;
            ActiveLookSDK.isActivatingBatteryNotif = false;
            ActiveLookSDK.isBatteryNotifActivated  = false;
            ActiveLookSDK.isActivatingALookTxNotif = false;
            ActiveLookSDK.isALookTxNotifActivated  = false;
            ActiveLookSDK.isReadingBattery         = false;
            ActiveLookSDK.batteryLevel             = null;
            ActiveLookSDK.isReadingFirmwareVersion = false;
            ActiveLookSDK.firmwareVersion          = null;
            ActiveLookSDK.isReadingCfgVersion      = false;
            ActiveLookSDK.cfgVersion               = null;
            ActiveLookSDK.isReadingFreeSpace       = false;
            ActiveLookSDK.isFreeSpaceRead          = false;
            ActiveLookSDK.isDeletingLessUsedCfg    = false;
            ActiveLookSDK.isLessUsedCfgDeleted     = false;
            
            ActiveLookSDK.isSavingPage             = false;
            ActiveLookSDK.isUpdatingALSSensor      = false;
            ActiveLookSDK.isUpdatingGestureSensor  = false;
            ActiveLookSDK.isReadingPageList        = false;
            ActiveLookSDK.isPagesRead              = false;
            ActiveLookSDK.isReadingPages           = false;
            ActiveLookSDK.isReadingPageList        = false;
            ActiveLookSDK.isPageListRead           = false;
            isWritingCharacteristic = false;
        }

        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onCharacteristicChanged
        function onCharacteristicChanged(characteristic as Toybox.BluetoothLowEnergy.Characteristic, value as Toybox.Lang.ByteArray) as Void {
            _log("onCharacteristicChanged", [characteristic, value]);
            if (value == null) {
                onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Characteristic change error $1$ $2$.", [characteristic, value])));
                return;
            }
            switch (characteristic.getUuid()) {
                case ble.getBleCharacteristicBatteryLevel().getUuid(): {
                    batteryLevel = value[0];
                    listener.onBatteryEvent(batteryLevel);
                    break;
                }
                case ble.getBleCharacteristicActiveLookGesture().getUuid(): {
                    if (value[0] != 0x01) {
                        _log("onCharacteristicChanged", ["Expecting gesture value 0x01", value]);
                    }
                    if (cmdStacking != null){
                        self.flushCmdStacking();
                    }
                    listener.onGestureEvent();
                    break;
                }
                case ble.getBleCharacteristicActiveLookTx().getUuid(): {
                    if (value.size() >= 2 && value[0] == 0xFF) {
                        switch (value[1]) {
                            case 0xD1 :{ // cfgRead
                            	cfgVersion = byteArrayToInt(value.slice(4,8),false);
                                isReadingCfgVersion = false;
                                _log("onCharacteristicChanged", ["cfgVersion", cfgVersion]);
                                listener.onCfgVersionEvent(cfgVersion);
                                setUpDevice();
                                break;
                            }
                            case 0xD7 :{ // freeSpace
                                var newFreeSpace = byteArrayToInt(value.slice(8,12),false);
                                _log("onCharacteristicChanged", ["freeSpace", newFreeSpace, freeSpace ]);
                                freeSpace = freeSpace == null || freeSpace != newFreeSpace ? newFreeSpace : -1;
                                isReadingFreeSpace = false;
                                isFreeSpaceRead = true;
                                //Check if there is enough free space available
                                if(freeSpace > -1 && freeSpace < freeSpaceLimit){ //need to delete cfg
                                    isDeletingLessUsedCfg = false;
                                    isLessUsedCfgDeleted  = false;
                                }else{ //don't need to delete cfg
                                    isDeletingLessUsedCfg = false;
                                    isLessUsedCfgDeleted = true;
                                }
                                listener.onFreeSpaceEvent(freeSpace);
                                setUpDevice();
                                break;
                            }
                            case 0x85 :{ // pageList
                                var pageList = value.slice(4, value.size() - 1);
                                for (var i = offsetIdPage; i <= offsetIdPage + 3; i++) {
                                    if (pageList.indexOf(i) != -1) {
                                        glassesPageList.add(i);
                                    }
                                }
                                _log("onCharacteristicChanged", ["pageList", glassesPageList]);
                                isReadingPageList = false;
                                isPageListRead = true;
                                setUpDevice();
                                break;
                            }
                            case 0x81 :{ // pageGet
                            	var id = byteArrayToInt(value.slice(4,5),false);
                                var data = value.slice(4, value.size() - 1);
                                glassesPageBuffer.add(data);
                                _log("onCharacteristicChanged", ["pageGet", id, data]);
                                if(glassesPageBuffer.size() == glassesPageList.size() ){
                                    isReadingPages = false;
                                    isPagesRead = true;
                                    setUpDevice();
                                }
                                break;
                            }
                            // case 0x0A: { // Settings
                            //     luma = value[6];
                            //     als = value[7];
                            //     gesture = value[8];
                            //     break;
                            // }
                            default: {
                                _log("__characteristicUpdate",[characteristic.getUuid().toString(), value.toString()]);
                            }
                        }
                        break;
                    }
                }
                default: {
                    onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Unknown characteristic $1$.", [characteristic])));
                    return;
                }
            }
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onCharacteristicRead
        function onCharacteristicRead(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void {
            _log("onCharacteristicRead", [characteristic, status, value]);
            switch (characteristic.getUuid()) {
                case ble.getBleCharacteristicBatteryLevel().getUuid(): {
                    isReadingBattery = false;
                    if (value != null) {
                        batteryLevel = value[0];
                        listener.onBatteryEvent(batteryLevel);
                        setUpDevice();
                        return;
                    }
                    break;
                }
                case ble.getBleCharacteristicFirmwareVersion().getUuid(): {
                    isReadingFirmwareVersion = false;
                    if (value != null) {
                        firmwareVersion = StringUtil.convertEncodedString(value, {
                                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                                :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                                :encoding => StringUtil.CHAR_ENCODING_UTF8
                            });
                        var major = 0;
                        var minor = 0;
                        var patch = 0;
                        var offset = firmwareVersion.find("v");
                        if (offset == null) { offset = -1; }
                        var subStr = firmwareVersion.substring(offset + 1, firmwareVersion.length());
                        major = subStr.toNumber();
                        offset = subStr.find(".");
                        if (offset != null) {
                            subStr = subStr.substring(offset + 1, subStr.length());
                            minor = subStr.toNumber();
                            offset = subStr.find(".");
                            if (offset != null) {
                                subStr = subStr.substring(offset + 1, subStr.length());
                                patch = subStr.toNumber();
                            }
                        }
                        
                        if(major > 4 || (major == 4  && minor >= 5)){
                            layoutCmdId = 0x6A;
                        }else{
                            layoutCmdId = 0x66;
                        }

                        listener.onFirmwareEvent(major, minor, patch);
                        setUpDevice();
                        return;
                    }
                    break;
                }
                default: {
                    isReadingBattery = false;
                    isReadingFirmwareVersion = false;
                    onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Unknown characteristic $1$.", [characteristic])));
                    return;
                }
            }
            onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Characteristic read error $1$ $2$ $3$.", [characteristic, status, value])));
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onCharacteristicWrite
        function onCharacteristicWrite(characteristic as Toybox.BluetoothLowEnergy.Characteristic, status as Toybox.BluetoothLowEnergy.Status) as Void {
            isWritingCharacteristic = false;
            _log("onCharacteristicWrite", [characteristic.getUuid(), status]);
            if (isUpdatingALSSensor && !isALSSensorUpdated) {
                isUpdatingALSSensor = false;
                if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    isALSSensorUpdated = true;
                }
            } else if (isUpdatingGestureSensor && !isGestureSensorUpdated) {
                isUpdatingGestureSensor = false;
                if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    isGestureSensorUpdated = true;
                }
            } else if(isDeletingLessUsedCfg && !isLessUsedCfgDeleted){
                isDeletingLessUsedCfg = false;
                if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    isLessUsedCfgDeleted = true;
                    isReadingFreeSpace   = false;
                    isFreeSpaceRead = false;
                }
            } else if(isSavingPage && !isPageSaved){
                isSavingPage = false;
                if (status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    isPageSaved = true;
                }
            }else {
                // TODO: Refactor to avoid callback like this
                var _cb = _cbCharacteristicWrite;
                if (_cb != null) {
                    _cb.invoke(characteristic, status);
                }else{
                    self.sendRawCmd([]b);
                }
            }
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onConnectedStateChanged
        function onConnectedStateChanged(device as Toybox.BluetoothLowEnergy.Device, state as Toybox.BluetoothLowEnergy.ConnectionState) as Void {
            _log("onConnectedStateChanged", [device, state]);
            if (state == Toybox.BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
                isPairing = false;
                setUpNewDevice(device);
            } else if (ActiveLookSDK.device == null) {
                onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Device was alread disconnected $1$ $2$.", [ActiveLookSDK.device, device])));
            } else if (ActiveLookSDK.device != device) {
                onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Device differs $1$ $2$.", [ActiveLookSDK.device, device])));
            } else {
                ActiveLookSDK.device = null;
                tearDownDevice();
                listener.onDeviceDisconnected();
            }
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onDescriptorRead
        function onDescriptorRead(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status, value as Toybox.Lang.ByteArray) as Void {
            _log("onDescriptorRead", [descriptor, status, value]);
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onDescriptorWrite
        function onDescriptorWrite(descriptor as Toybox.BluetoothLowEnergy.Descriptor, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onDescriptorWrite", [descriptor, status]);
            var isActivated = status == Toybox.BluetoothLowEnergy.STATUS_SUCCESS;
            switch (descriptor.getCharacteristic().getUuid()) {
                case ble.getBleCharacteristicBatteryLevel().getUuid(): {
                    isActivatingBatteryNotif = false;
                    if (isActivated) { isBatteryNotifActivated = true; }
                    break;
                }
                case ble.getBleCharacteristicActiveLookTx().getUuid(): {
                    isActivatingALookTxNotif = false;
                    if (isActivated) { isALookTxNotifActivated = true; }
                    break;
                }
                case ble.getBleCharacteristicActiveLookGesture().getUuid(): {
                    isActivatingGestureNotif = false;
                    if (isActivated) { isGestureNotifActivated = true; }
                    break;
                }
                default: {
                    isActivatingALookTxNotif = false;
                    isActivatingBatteryNotif = false;
                    isActivatingGestureNotif = false;
                    onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Unknown descriptor $1$ $2$.", [descriptor.getCharacteristic(), descriptor, status])));
                    return;
                }
            }
            if (!isActivated) {
                onBleError(new Toybox.Lang.InvalidValueException(Toybox.Lang.format("(E) Descriptor write error $1$ $2$.", [descriptor.getCharacteristic(), descriptor, status])));
                return;
            }
            setUpDevice();
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onScanResult
        function onScanResult(scanResult as Toybox.BluetoothLowEnergy.ScanResult) as Void {
            _log("onScanResult", [scanResult]);
            listener.onScanResult(scanResult);
        }
        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onScanStateChange
        function onScanStateChange(scanState as Toybox.BluetoothLowEnergy.ScanState, status as Toybox.BluetoothLowEnergy.Status) as Void {
            _log("onScanStateChange", [scanState, status]);
            if (scanState == Toybox.BluetoothLowEnergy.SCAN_STATE_SCANNING) {
                if (status <= Toybox.BluetoothLowEnergy.STATUS_SUCCESS) {
                    isScanning = true;
                }
            } else {
                isScanning = false;
            }
        }

        // Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onPassiveConnection
        function onPassiveConnection(device as Toybox.BluetoothLowEnergy.Device) as Void {
            ActiveLookSDK.device = device;
        }

        function cfgWrite() {
            try {
                var data = [0x41, 0x4C, 0x6F, 0x6F, 0x4B]b; // ALooK Magic number
                data.addAll(numberToFixedSizeByteArray(cfgVersion, 5)); // version
                data.addAll([0x9E, 0x56, 0x5B, 0xF9]b); // ALooK Magic number
                self.sendRawCmd(self.commandBuffer(0xD0, data));
            } catch (e) {
                isSavingPage = false;
                onBleError(e);
            }
        }

        function pageSave(buffer) {
            try {
                _log("pageSave",[buffer]);
                self.sendRawCmd(self.commandBuffer(0x80, buffer));
            } catch (e) {
                isSavingPage = false;
                onBleError(e);
            }
        }


        function pageDisplay(id, buffer) {
            if(buffer.size() == 0){return;}
            var idOffsetted = id + offsetIdPage;
            _log("pageDisplay",[idOffsetted]);
            var data = numberToByteArray(idOffsetted);
            data.addAll(buffer);
            self.sendRawCmd(self.commandBuffer(0x86, data));
        }

        function widgetsDisplay() {
            for (var i = 0; i < $.widgets.size(); i++) {
                _log("widgetDisplay",[i]);
                self.sendRawCmd(self.commandBuffer(0x3A, $.widgets[i]));
            }
        }

        //! Override ActiveLookBLE.ActiveLook.ActiveLookDelegate.onBleError
        function onBleError(exception as Toybox.Lang.Exception) as Void {
            _log("onBleError", [exception.getErrorMessage()]);
            listener.onBleError(exception);
        }
   
        function splitString(input as Toybox.Lang.String, delimiter as Toybox.Lang.String) as Toybox.Lang.Array {
            var result = [];
            var current = "";
            for (var i = 0; i < input.length(); i++) {
                if (input.substring(i, i + 1).equals(delimiter)) {
                    result.add(current);
                    current = "";
                } else {
                    current += input.substring(i, i + 1);
                }
            }
            result.add(current);
            return result;
        }

    }

}
