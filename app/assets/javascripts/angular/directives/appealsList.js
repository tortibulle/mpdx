angular.module('mpdxApp')
    .directive('appealsList', function () {
        return {
            restrict: 'E',
            templateUrl: '/templates/appeals/list.html',
            controller: function ($scope, api) {
                api.call('get','appeals?account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                    $scope.appeals = data;
                }, null);

            }
        };
    });