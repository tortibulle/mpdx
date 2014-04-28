angular.module('mpdxApp')
    .service('api', function ($rootScope, $http) {
        var apiUrl = '/api/v1/';

        this.call = function (method, url, data, successFn, errorFn) {
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
                }).
                error(function(data, status) {
                    console.log('API ERROR: ' + status);
                    if(_.isFunction(errorFn)){
                        errorFn(data, status);
                    }
                });
        };
    });