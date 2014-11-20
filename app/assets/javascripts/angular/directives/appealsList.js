angular.module('mpdxApp')
    .directive('appealsList', function () {
        return {
            restrict: 'E',
            templateUrl: '/templates/appeals/list.html',
            controller: function ($scope, $modal, api) {
                var refreshAppeals = function(){
                    api.call('get','appeals?account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                        $scope.appeals = data.appeals;
                    });
                };
                refreshAppeals();

                $scope.editAppeal = function(id) {
                    var modalInstance = $modal.open({
                        templateUrl: '/templates/appeals/edit.html',
                        controller: function($scope, $modalInstance, appeal){
                            $scope.appeal = angular.copy(appeal);
                            $scope.checkedContacts = {};
                            $scope.taskTypes = window.railsConstants.task.ACTIONS;

                            api.call('get','contacts?filters[status]=*&per_page=5000&include=Contact.id,Contact.name,Contact.donor_accounts&account_list_id=' + (window.current_account_list_id || ''), {}, function(data) {
                                $scope.contacts = data.contacts;
                                $scope.newContact = data.contacts[0].id;
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

                            $scope.listDonations = function(contactId){
                                var contact = _.find($scope.contacts, { 'id': contactId });
                                if(angular.isUndefined(contact) || angular.isUndefined(contact.donor_accounts)){
                                    return '-';
                                }
                                var contactDonorIds = _.flatten(contact.donor_accounts, 'id');
                                var donations = _.where(appeal.donations, function(d) {
                                    return _.contains(contactDonorIds, d.donor_account_id);
                                });

                                if(!donations.length){
                                    return ['-'];
                                }else{
                                    var str = [];
                                    angular.forEach(donations, function(d){
                                        str.push(d.donation_date + ' - $' + $scope.formatNumber(d.amount));
                                    });
                                    return str;
                                }
                            };

                            $scope.createTask = function(taskType, inputContactsObject){
                                var contactsObject = [];
                                angular.forEach(inputContactsObject, function(value, key) {
                                    if(value){
                                        contactsObject.push(_.zipObject(['contact_id'], [parseInt(key)]));
                                    }
                                });

                                if(!contactsObject.length){
                                    alert('You must check at least one contact.');
                                    return;
                                }

                                api.call('post', 'tasks/?account_list_id=' + window.current_account_list_id, {
                                    task: {
                                        start_at: moment().add(7, 'days').format('YYYY-MM-DD HH:mm:ss'),
                                        subject: 'Appeal (' + $scope.appeal.name + ')',
                                        activity_type: taskType,
                                        activity_contacts_attributes: contactsObject
                                    }
                                }, function () {
                                    alert('Task created.');
                                    $scope.taskType = '';
                                });
                            };

                            $scope.selectAll = function(type){
                                if(type === 'all'){
                                    angular.forEach($scope.appeal.contacts, function (c) {
                                        $scope.checkedContacts[c] = true;
                                    });
                                }else if(type === 'none'){
                                    $scope.checkedContacts = {};
                                }else if(type === 'donated'){
                                    angular.forEach($scope.appeal.contacts, function (c) {
                                        if(_.first($scope.listDonations(c)) === '-'){
                                            $scope.checkedContacts[c] = false;
                                        }else{
                                            $scope.checkedContacts[c] = true;
                                        }
                                    });
                                }else if(type === '!donated'){
                                    angular.forEach($scope.appeal.contacts, function (c) {
                                        if(_.first($scope.listDonations(c)) === '-'){
                                            $scope.checkedContacts[c] = true;
                                        }else{
                                            $scope.checkedContacts[c] = false;
                                        }
                                    });
                                }
                            };
                        },
                        resolve: {
                            appeal: function () {
                                return _.find($scope.appeals, { 'id': id });
                            }
                        }
                    });

                    modalInstance.result.then(function (updatedAppeal) {
                        var index = _.findIndex($scope.appeals, { 'id': updatedAppeal.id });
                        $scope.appeals[index] = updatedAppeal;
                    });
                };

                $scope.deleteAppeal = function(id){
                    var r = confirm('Are you sure you want to delete this appeal?');
                    if(!r){
                        return;
                    }
                    api.call('delete', 'appeals/' + id + '?account_list_id=' + (window.current_account_list_id || ''), null, function() {
                        refreshAppeals();
                    });
                };

                $scope.donationTotal = function(donations){
                    donations = _.flatten(donations, 'amount');
                    return donations.reduce(function(pv, cv) { return Number(pv) + Number(cv); }, 0);
                };

                $scope.percentComplete = function(donations, total){
                    total = Number(total);
                    if(total === 0){
                        return 0;
                    }
                    donations = _.flatten(donations, 'amount');
                    var sum = donations.reduce(function(pv, cv) { return pv + Number(cv); }, 0);
                    return parseInt((sum / total) * 100);
                };

                $scope.newAppeal = function(){
                    var modalInstance = $modal.open({
                        templateUrl: '/templates/appeals/wizard.html',
                        controller: function($scope, $modalInstance){
                            $scope.appeal = {};
                            $scope.contactStatuses = window.railsConstants.contact.ACTIVE_STATUSES.concat(window.railsConstants.contact.INACTIVE_STATUSES).sort();

                            $scope.cancel = function () {
                                $modalInstance.dismiss('cancel');
                            };

                            $scope.save = function () {
                                $modalInstance.close($scope.appeal);
                            };
                        }
                    }).result.then(function (newAppeal) {
                        var statusCount = 0;
                        var strContactsUrl = 'contacts?per_page=5000&include=Contact.id&account_list_id=' + (window.current_account_list_id || '');
                        angular.forEach(newAppeal.validStatus, function(value, key) {
                            if(value){
                                strContactsUrl = strContactsUrl + '&filters[status][]=' + encodeURIComponent(key);
                                statusCount++;
                            }
                        });

                        var contactsObject = [];
                        api.call('get', strContactsUrl, {}, function(data) {
                            if(statusCount > 0){
                                angular.forEach(data.contacts, function(c) {
                                    contactsObject.push(c.id);
                                });
                            }

                            api.call('post', 'appeals/?account_list_id=' + (window.current_account_list_id || ''), {
                                name: newAppeal.name,
                                amount: newAppeal.amount,
                                contacts: contactsObject,
                                account_list_id: (window.current_account_list_id || '')
                            }, function() {
                                refreshAppeals();
                            });
                        });
                    });
                };

                $scope.formatNumber = function(number){
                  return Number(number).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
                };
            }
        };
    });