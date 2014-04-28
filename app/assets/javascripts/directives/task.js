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
            controller: function ($scope, contactCache, api) {
                $scope.contacts = {};
                angular.forEach($scope.task.contacts, function(contactId){
                    contactCache.get(contactId, function(contact){
                        $scope.contacts[contactId] = contact.contact.name;
                    });
                })

                //complete options
                if($scope.task.activity_type === 'Call') {
                    $scope.completeOptions = ['Attempted', 'Done'];
                }else if(_.contains(['Email', 'Text Message', 'Facebook Message', 'Letter'], $scope.task.activity_type)){
                    $scope.completeOptions = ['Done', 'Received'];
                }else{
                    $scope.completeOptions = ['Done'];
                }

                $scope.getComment = function(id){
                    return _.find($scope.$parent.comments, { 'id': id });
                };

                $scope.getPerson = function(id){
                    var person = _.find($scope.$parent.people, { 'id': id });
                    person.name = person.first_name + ' ' + person.last_name;
                    return person;
                };

                $scope.starTask = function(){
                    $scope.task.starred = !$scope.task.starred;
                    api.call('put', 'tasks/'+$scope.task.id, {
                        task: $scope.task
                    });
                };

                $scope.markComplete = function(){
                    //$scope.task.completed = true;
                    api.call('put', 'tasks/'+$scope.task.id, {
                        task: $scope.task
                    }, function(){
                        _.remove($scope.$parent.tasks, function(task) { return task.id === $scope.task.id; });
                    });
                };

                $scope.postNewComment = function(){
                    api.call('put', 'tasks/'+$scope.task.id, {
                        task: {
                            activity_comments_attributes: {
                                "0": {
                                    body: $scope.postNewCommentMsg
                                }}
                        }
                    }, function(data){
                        var latestComment = _.max(data.comments, function(comment) { return comment.id; });
                        $scope.$parent.comments.push(latestComment);
                        $scope.task.comments.push(latestComment.id);
                        $scope.postNewCommentMsg = '';
                    });
                }
            }
        };
    });