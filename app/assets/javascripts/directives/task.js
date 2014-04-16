angular.module('mpdxApp')
    .directive('task', function () {
        return {
            restrict: 'A',
            templateUrl: '/templates/tasks/task.html',
            scope: {
                task: '='
            },
            link: function (scope, element, attrs){
            },
            controller: function ($scope, contactCache) {
                $scope.contacts = {};
                console.log($scope.task);

                angular.forEach($scope.task.contacts, function(contactId){
                    contactCache.get(contactId, function(contact){
                        $scope.contacts[contactId] = contact.contact.name;
                    });
                })

                $scope.getComment = function(id){
                    return _.find($scope.$parent.comments, { 'id': id });
                };
            }
        };
    });