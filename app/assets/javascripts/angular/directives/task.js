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
                $scope.visibleComments = false;

                $scope.contacts = {};
                angular.forEach($scope.task.contacts, function(contactId){
                    contactCache.get(contactId, function(contact){
                        $scope.contacts[contactId] = contact.contact.name;
                    });
                })

                //complete options
                if($scope.task.activity_type === 'Call') {
                    $scope.completeOptions = ['Done', 'Attempted - Left Message', 'Attempted - Call Again', 'Complete - Call Again', 'Appointment Scheduled', 'Partner - Financial', 'Partner - Special', 'Partner - Pray', 'Ask in Future', 'Not Interested'];
                }else if($scope.task.activity_type === 'Appointment') {
                    $scope.completeOptions = ['Done', 'Decision Received', 'Call for Decision', 'Partner - Financial', 'Attempted - Reschedule'];
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
                };

                $scope.showContactInfo = function(contactId){
                    if($scope.visibleContactInfo && $scope.contactInfo.contact.id === contactId){
                        $scope.visibleContactInfo = false;
                        return;
                    }else{
                        $scope.visibleContactInfo = true;
                        $scope.visibleComments = false;
                    }


                    contactCache.get(contactId, function(contact){
                        var returnContact = angular.copy(contact);
                        returnContact.phone_numbers = [];
                        returnContact.email_addresses = [];

                        angular.forEach(contact.people, function(i){
                            var person = _.find(contact.people, { 'id': i.id });

                            var phone = _.filter(contact.phone_numbers, function(i){
                                return _.contains(person.phone_number_ids, i.id);
                            });
                            if(phone.length > 0){
                                returnContact.phone_numbers = _.union(returnContact.phone_numbers, phone);
                            }

                            var email = _.filter(contact.email_addresses, function(i){
                                return _.contains(person.email_address_ids, i.id);
                            });
                            if(email.length > 0){
                                returnContact.email_addresses = _.union(returnContact.email_addresses, email);
                            }
                        });

                        $scope.contactInfo = returnContact;
                    });
                };
            }
        };
    });