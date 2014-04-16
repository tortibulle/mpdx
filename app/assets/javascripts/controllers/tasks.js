angular.module('mpdxApp').controller('tasksController', function ($scope, $http, $filter) {
    $scope.refreshTasks = function(){
        $http({method: 'GET', url: '/api/v1/tasks'}).
            success(function(data, status, headers, config) {
                $scope.tasks = data.tasks;
                $scope.comments = data.comments;
                //console.log(data);
            }).
            error(function(data, status, headers, config) {
                // called asynchronously if an error occurs
                // or server returns response with an error status.
            });
    };
    $scope.refreshTasks();
    $scope.filterContactsSelect = [''];

    $scope.$watch('filterContactsSelect', function(newValue, oldValue){
        //console.log(newValue);
    })

    $scope.filters = function(task){
        if($scope.filterContactsSelect[0] === ''){
            return true;
        }
        var result = false;
        angular.forEach(task.contacts, function(contact){
            if(_.contains($scope.filterContactsSelect, contact.toString())){
                result = true;
            }
        });
        return result;
    };

    $scope.filterToday = function(task) {
        return ($filter('date')(task.due_date, 'yyyyMMdd') === $filter('date')(Date.now(), 'yyyyMMdd'));
    };

    $scope.filterOverdue= function(task) {
        return ($filter('date')(task.due_date, 'yyyyMMdd') < $filter('date')(Date.now(), 'yyyyMMdd'));
    };

    $scope.filterTomorrow= function(task) {
        return ($filter('date')(task.due_date, 'yyyyMMdd') === $filter('date')(new Date(new Date().getTime() + 24 * 60 * 60 * 1000), 'yyyyMMdd'));
    };

    $scope.filterUpcoming= function(task) {
        return ($filter('date')(task.due_date, 'yyyyMMdd') > $filter('date')(new Date(new Date().getTime() + 24 * 60 * 60 * 1000), 'yyyyMMdd'));
    };
});