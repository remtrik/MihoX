package main

import (
	"encoding/json"
	"unsafe"

	"github.com/metacubex/mihomo/constant"
)

type Action struct {
	Id     string      `json:"id"`
	Method Method      `json:"method"`
	Data   interface{} `json:"data"`
}

type ActionResult struct {
	Id       string         `json:"id"`
	Method   Method         `json:"method"`
	Data     interface{}    `json:"data"`
	Code     int            `json:"code"`
	Port     int64          `json:"-"`
	Callback unsafe.Pointer `json:"-"`
}

func (result ActionResult) Json() ([]byte, error) {
	data, err := json.Marshal(result)
	return data, err
}

func (result ActionResult) success(data interface{}) {
	result.Code = 0
	result.Data = data
	result.send()
}

func (result ActionResult) error(data interface{}) {
	result.Code = -1
	result.Data = data
	result.send()
}

func handleAction(action *Action, result ActionResult) {
	switch action.Method {
	case initMihomoMethod:
		paramsString := action.Data.(string)
		result.success(handleInitMihomo(paramsString))
	case getIsInitMethod:
		result.success(handleGetIsInit())
	case forceGcMethod:
		handleForceGc()
		result.success(true)
	case shutdownMethod:
		result.success(handleShutdown())
	case validateConfigMethod:
		data := []byte(action.Data.(string))
		result.success(handleValidateConfig(data))
	case updateConfigMethod:
		data := []byte(action.Data.(string))
		result.success(handleUpdateConfig(data))
	case setupConfigMethod:
		data := []byte(action.Data.(string))
		result.success(handleSetupConfig(data))
	case getProxiesMethod:
		result.success(handleGetProxies())
	case changeProxyMethod:
		data := action.Data.(string)
		handleChangeProxy(data, func(value string) {
			result.success(value)
		})
	case getTrafficMethod:
		result.success(handleGetTraffic())
	case getTotalTrafficMethod:
		result.success(handleGetTotalTraffic())
	case resetTrafficMethod:
		handleResetTraffic()
		result.success(true)
	case asyncTestDelayMethod:
		data := action.Data.(string)
		handleAsyncTestDelay(data, func(value string) {
			result.success(value)
		})
	case getConnectionsMethod:
		result.success(handleGetConnections())
	case closeConnectionsMethod:
		result.success(handleCloseConnections())
	case resetConnectionsMethod:
		result.success(handleResetConnections())
	case getConfigMethod:
		path := action.Data.(string)
		config, err := handleGetConfig(path)
		if err != nil {
			result.error(err)
			return
		}
		result.success(config)
	case getCoreVersionMethod:
		result.success(constant.Version)
	case closeConnectionMethod:
		id := action.Data.(string)
		result.success(handleCloseConnection(id))
	case getExternalProvidersMethod:
		result.success(handleGetExternalProviders())
	case getExternalProviderMethod:
		externalProviderName := action.Data.(string)
		result.success(handleGetExternalProvider(externalProviderName))
	case updateGeoDataMethod:
		paramsString := action.Data.(string)
		var params = map[string]string{}
		err := json.Unmarshal([]byte(paramsString), &params)
		if err != nil {
			result.success(err.Error())
			return
		}
		geoType := params["geo-type"]
		geoName := params["geo-name"]
		handleUpdateGeoData(geoType, geoName, func(value string) {
			result.success(value)
		})
	case updateExternalProviderMethod:
		providerName := action.Data.(string)
		handleUpdateExternalProvider(providerName, func(value string) {
			result.success(value)
		})
	case sideLoadExternalProviderMethod:
		paramsString := action.Data.(string)
		var params = map[string]string{}
		err := json.Unmarshal([]byte(paramsString), &params)
		if err != nil {
			result.success(err.Error())
			return
		}
		providerName := params["providerName"]
		data := params["data"]
		handleSideLoadExternalProvider(providerName, []byte(data), func(value string) {
			result.success(value)
		})
	case startLogMethod:
		handleStartLog()
		result.success(true)
	case stopLogMethod:
		handleStopLog()
		result.success(true)
	case startListenerMethod:
		result.success(handleStartListener())
	case stopListenerMethod:
		result.success(handleStopListener())
	case getCountryCodeMethod:
		ip := action.Data.(string)
		handleGetCountryCode(ip, func(value string) {
			result.success(value)
		})
	case getMemoryMethod:
		handleGetMemory(func(value string) {
			result.success(value)
		})
	case setStateMethod:
		data := action.Data.(string)
		handleSetState(data)
		result.success(true)
	case healthCheckMethod:
		groupName, _ := action.Data.(string)
		handleHealthCheck(groupName, func(value string) {
			result.success(value)
		})
	case convertV2rayMethod:
		data := action.Data.(string)
		result.success(handleConvertV2ray(data))
	case crashMethod:
		result.success(true)
		handleCrash()
	default:
		nextHandle(action, result)
	}
}
