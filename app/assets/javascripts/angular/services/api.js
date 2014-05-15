angular.module('mpdxApp')
    .service('api', function ($rootScope, $http, $cacheFactory) {
        var apiUrl = '/api/v1/';
        var apiCache = $cacheFactory('api');

        this.call = function (method, url, data, successFn, errorFn, cache) {
            if(cache === true){
                var cachedData = apiCache.get(url);
                if (angular.isDefined(cachedData)) {
                    successFn(cachedData, 200);
                    return;
                }
            }
            $http({
                method: method,
                url: apiUrl + url,
                data: data,
                cache: false,
                timeout: 50000
            }).
                success(function(data, status) {
                    if(_.isFunction(successFn)){
                        successFn(data, status);
                    }
                    if(cache === true){
                        apiCache.put(url, data);
                    }
                }).
                error(function(data, status) {
                    console.log('API ERROR: ' + status);
                    if(_.isFunction(errorFn)){
                        errorFn(data, status);
                    }
                });
        };
    });