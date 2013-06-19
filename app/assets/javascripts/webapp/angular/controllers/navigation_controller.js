myApp.controller('navCtrl', ['$scope', '$location', function ($scope, $location) {
    $scope.navClass = function (page) {
        var currentRoute = $location.path().split("/")[1] || 'home';
        return page === currentRoute ? 'active' : '';
    };
}]);
