angular.module('mpdxApp')
    .directive('taskFollowupDialog', function () {
        return {
            restrict: 'E',
            templateUrl: '/templates/tasks/followupDialog.html',
            controller: function ($scope, api) {
                $scope.followUpDialog = function(taskId, taskResult){
                    var mergedTasks = [];
                    _($scope.tasks).forEach(function(i) { mergedTasks.push(i); });
                    var followUpTask = _.find(_.flatten(mergedTasks), { 'id': parseInt(taskId) });

                    var contactsObject = [];
                    angular.forEach(followUpTask.contacts, function(c){
                        contactsObject.push(_.zipObject(['contact_id'], [c]));
                    });

                    delete $scope.followUpDialogData;
                    $scope.followUpDialogResult = {};

                    if(followUpTask.activity_type === 'Appointment'){
                        if(taskResult === 'Decision Received' && followUpTask.contacts.length > 0){
                            $scope.followUpDialogData = {
                                'message': 'Update related contact(s) status to:',
                                'options': ['Ask in Future', 'Partner - Financial', 'Partner - Special', 'Partner - Pray', 'Not Interested']
                            };
                            $scope.followUpSaveFunc = function(){
                                angular.forEach(followUpTask.contacts, function(c){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            status: $scope.followUpDialogResult.select
                                        }
                                    });
                                });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }else if(taskResult === 'Call for Decision' || taskResult === 'Attempted - Reschedule') {
                            $scope.followUpDialogData = {
                                'message': 'Would you like to create a task to make a call in the future?',
                                'options': ['Yes, 1 week from now', 'Yes, 2 weeks from now', 'Yes, tomorrow']
                            };
                            $scope.followUpSaveFunc = function () {
                                var taskDueDate = new Date();
                                if($scope.followUpDialogResult.select === 'Yes, 1 week from now') {
                                    taskDueDate = new Date(taskDueDate.getTime() + (7 * 24 * 60 * 60 * 1000));
                                }else if($scope.followUpDialogResult.select === 'Yes, 2 weeks from now'){
                                    taskDueDate = new Date(taskDueDate.getTime() + (14 * 24 * 60 * 60 * 1000));
                                }else if($scope.followUpDialogResult.select === 'Yes, tomorrow'){
                                    taskDueDate = new Date(taskDueDate.getTime() + (24 * 60 * 60 * 1000));
                                }
                                api.call('post', 'tasks/', {
                                    task: {
                                        start_at: taskDueDate.toISOString(),
                                        subject: 'Call for Decision',
                                        activity_type: 'Call',
                                        activity_contacts_attributes: contactsObject
                                    }
                                }, function(){ $scope.refreshVisibleTasks(); });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }else if(taskResult === 'Partner - Financial' && followUpTask.contacts.length > 0){
                            $scope.followUpDialogData = {
                                'message': 'Set contact\'s status to \'Partner - Financial?\':',
                                'options': ['Yes'],
                                'showFrequency': true,
                                'dateLabel': 'Commitment Start Date',
                                'showDate': true,
                                'showAmount': true
                            };
                            $scope.followUpSaveFunc = function(){
                                angular.forEach(followUpTask.contacts, function(c){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            status: 'Partner - Financial',
                                            pledge_amount: $scope.followUpDialogResult.amount,
                                            pledge_frequency: $scope.followUpDialogResult.frequency,
                                            pledge_start_date: $scope.followUpDialogResult.date
                                        }
                                    });
                                });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }
                    }else if(followUpTask.activity_type === 'Call'){
                        if(taskResult === 'Attempted - Left Message' || taskResult === 'Complete - Call Again' || taskResult === 'Attempted - Call Again') {
                            $scope.followUpDialogData = {
                                'message': 'Schedule a followup call?',
                                'options': ['Yes'],
                                'showFrequency': false,
                                'dateLabel': 'Follow up task due date:',
                                'showDate': true,
                                'showAmount': false
                            };
                            $scope.followUpSaveFunc = function () {
                                api.call('post', 'tasks/', {
                                    task: {
                                        start_at: $scope.followUpDialogResult.date,
                                        subject: followUpTask.subject,
                                        activity_type: 'Call',
                                        activity_contacts_attributes: contactsObject
                                    }
                                }, function () {
                                    $scope.refreshVisibleTasks();
                                });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }else if(taskResult === 'Decision Received' && followUpTask.contacts.length > 0){
                            $scope.followUpDialogData = {
                                'message': 'Update related contact(s) status to:',
                                'options': ['Ask in Future', 'Partner - Financial', 'Partner - Special', 'Partner - Pray', 'Not Interested']
                            };
                            $scope.followUpSaveFunc = function(){
                                angular.forEach(followUpTask.contacts, function(c){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            status: $scope.followUpDialogResult.select
                                        }
                                    });
                                });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }else if(taskResult === 'Partner - Financial' && followUpTask.contacts.length > 0){
                            $scope.followUpDialogData = {
                                'message': 'Set contact\'s status to \'Partner - Financial?\':',
                                'options': ['Yes'],
                                'showFrequency': true,
                                'dateLabel': 'Commitment Start Date',
                                'showDate': true,
                                'showAmount': true
                            };
                            $scope.followUpSaveFunc = function(){
                                angular.forEach(followUpTask.contacts, function(c){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            status: 'Partner - Financial',
                                            pledge_amount: $scope.followUpDialogResult.amount,
                                            pledge_frequency: $scope.followUpDialogResult.frequency,
                                            pledge_start_date: $scope.followUpDialogResult.date
                                        }
                                    });
                                });
                                jQuery('#complete_task_followup_modal').dialog('close');
                            };
                        }
                    }

                    if(angular.isDefined($scope.followUpDialogData)){
                        $scope.followUpDialogResult.select = $scope.followUpDialogData.options[0];
                        $scope.$apply();
                        jQuery("#complete_task_followup_modal").dialog({
                            autoOpen: true,
                            modal: true
                        });

                        if($scope.followUpDialogData.showDate){
                            jQuery('#followUpDialogDatepicker').datepicker({ dateFormat: 'yy-mm-dd' });
                        }
                    }
                };
            }
        };
    });