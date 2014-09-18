angular.module('mpdxApp')
    .directive('appealsList', function () {
        return {
            restrict: 'E',
            templateUrl: '/templates/appeals/list.html',
            controller: function ($scope, $modal, api) {
                api.call('get','appeals?account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                    $scope.appeals = data.appeals;
                });

                $scope.editAppeal = function(id) {
                    var modalInstance = $modal.open({
                        templateUrl: '/templates/appeals/edit.html',
                        controller: function($scope, $modalInstance, appeal){
                            $scope.appeal = angular.copy(appeal);
                            console.log($scope.appeal);

                            api.call('get','contacts?account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                                $scope.contacts = data.contacts;
                            }, null, true);

                            $scope.cancel = function () {
                                $modalInstance.dismiss('cancel');
                            };

                            $scope.save = function () {
                                api.call('put','appeals/'+ $scope.appeal.id + '?account_list_id=' + (window.current_account_list_id || ''),
                                    {"appeal": $scope.appeal},
                                    function(data) {
                                        $modalInstance.close($scope.appeal);
                                    });
                            };

                            $scope.contactName = function(id){
                                var contact = _.find($scope.contacts, { 'id': id });
                                if(angular.isDefined(contact)){
                                    return contact.name;
                                }
                                return '';
                            };

                            $scope.addContact = function(id){
                                if(!id){ return; }
                                if(_.contains($scope.appeal.contacts, id)){
                                    alert('This contact already exists in this appeal.');
                                    return;
                                }
                                $scope.appeal.contacts.push(id);
                            };

                            $scope.deleteContact = function(id){
                                _.remove($scope.appeal.contacts, function(c) { return c == id; });
                            };
                        },
                        resolve: {
                            appeal: function () {
                                return _.find($scope.appeals, { 'id': id });
                            }
                        }
                    });

                    modalInstance.result.then(function (updatedAppeal) {
                        var index = _.findIndex($scope.appeals, { 'id': updatedAppeal.id })
                        $scope.appeals[index] = updatedAppeal;
                    }, function () {
                        //$log.info('Modal dismissed at: ' + new Date());
                    });
                };

                $scope.deleteAppeal = function(id){
                    var r = confirm('Are you sure you want to delete this appeal?');
                    if(!r){
                        return;
                    }
                    api.call('delete','appeals/' + id + '?account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                        //$scope.contacts = data.contacts;
                    });
                };
            }
        };
    });