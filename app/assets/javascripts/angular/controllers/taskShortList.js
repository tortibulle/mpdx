angular.module('mpdxApp').controller('taskShortListController', function ($scope, api, $location, contactCache) {
    $scope.init = function(page, contactId) {
        $scope.tasks = {};
        $scope.comments = {};
        $scope.people = {};

        if(page === 'contact') {
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=false' +
                '&filters[contact_ids][]=' + contactId +
                '&per_page=' + 5 +
                '&page=' + 1;
        }else if(page === 'contactHistory'){
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=true' +
                '&filters[contact_ids][]=' + contactId +
                '&per_page=' + 5 +
                '&page=' + 1;
        }else{
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=false' +
                '&per_page=' + 5 +
                '&page=' + 1;
        }

        api.call('get', taskUrl, {}, function(tData) {
            if (tData.tasks.length === 0) {
                return;
            }

            //retrieve contacts
            api.call('get', 'contacts?account_list_id=' + window.current_account_list_id +
                '&filters[status]=*&filters[ids]=' + _.uniq(_.flatten(tData.tasks, 'contacts')).join(), {}, function (data) {
                angular.forEach(data.contacts, function (contact) {
                    contactCache.update(contact.id, {
                        addresses: _.filter(data.addresses, function (addr) {
                            return _.contains(contact.address_ids, addr.id);
                        }),
                        people: _.filter(data.people, function (i) {
                            return _.contains(contact.person_ids, i.id);
                        }),
                        email_addresses: data.email_addresses,
                        contact: _.find(data.contacts, { 'id': contact.id }),
                        phone_numbers: data.phone_numbers,
                        facebook_accounts: data.facebook_accounts
                    });
                });

                $scope.tasks = tData.tasks;
                $scope.comments = _.union(tData.comments, $scope.comments);
                $scope.people = _.union(tData.people, $scope.people);
            }, null, true);
        });
    };
});