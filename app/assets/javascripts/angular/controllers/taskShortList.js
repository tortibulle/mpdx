angular.module('mpdxApp').controller('taskShortListController', function ($scope, api, $location, contactCache) {
    $scope.init = function(page, contactId) {
        $scope.tasks = {};
        $scope.comments = {};
        $scope.people = {};
        $scope.history = page == 'contactHistory';

        if(page === 'contact') {
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=false' +
                '&filters[contact_ids][]=' + contactId +
                '&per_page=' + 500 +
                '&page=' + 1 +
                '&order=start_at';
        }else if(page === 'contactHistory'){
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=true' +
                '&filters[contact_ids][]=' + contactId +
                '&per_page=' + 500 +
                '&page=' + 1 +
                '&order=completed_at desc';
        }else{
            var taskUrl = 'tasks?account_list_id=' + window.current_account_list_id +
                '&filters[completed]=false' +
                '&per_page=' + 5 +
                '&page=' + 1 +
                '&order=start_at';
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

    $scope.syncTask = function(task) {
        if(task.start_at)
            task.due_date = task.start_at;
        var old_task = _.findWhere($scope.tasks, {id: task.id});
        if(!old_task)
            $scope.addTask(task)
        else if($scope.history == task.completed)
            $scope.updateTask(old_task, task)
        else
            $scope.removeTask(task)
        $scope.$digest();
    };

    $scope.addTask = function(newTask) {
        $scope.tasks.push(task);
    };

    $scope.updateTask = function(oldTask, newTask) {
        var fields_to_update = ['subject', 'due_date', 'starred', 'activity_type'];
        for(var i in fields_to_update) {
            oldTask[fields_to_update[i]] = newTask[fields_to_update[i]];
        }
    };

    $scope.removeTask = function(oldTask) {
        var index = $scope.tasks.indexOf(oldTask);
        if(index != -1)
            $scope.tasks.splice(index, 1);
    };
});
