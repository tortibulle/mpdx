angular.module('mpdxApp')
    .directive('taskFollowupDialog', function () {
        return {
            restrict: 'E',
            templateUrl: '/templates/tasks/followupDialog.html',
            controller: function ($scope, api) {
                $scope.followUpDialog = function(taskId, taskResult){

                    ////////////  testing  ////////////
                    if(!window.current_account_list_tester){
                        //return;
                    }
                    ////////////  end testing  ////////////

                    var mergedTasks = [];
                    _($scope.tasks).forEach(function(i) { mergedTasks.push(i); });
                    var followUpTask = _.find(_.flatten(mergedTasks), { 'id': parseInt(taskId) });

                    var contactsObject = [];
                    angular.forEach(followUpTask.contacts, function(c){
                        contactsObject.push(_.zipObject(['contact_id'], [c]));
                    });

                    delete $scope.followUpDialogData;
                    $scope.followUpDialogResult = {};



                    var dateTwoDaysFromToday = new Date();
                    dateTwoDaysFromToday.setDate(dateTwoDaysFromToday.getDate() + 2);
                    dateTwoDaysFromToday = dateTwoDaysFromToday.getFullYear() + '-' + ("0" + (dateTwoDaysFromToday.getMonth() + 1)).slice(-2) + '-' + ("0" + dateTwoDaysFromToday.getDate()).slice(-2);



                    if(taskResult === 'Attempted - Left Message' || taskResult === 'Complete - Call Again' || taskResult === 'Attempted - Call Again') {

                        $scope.followUpDialogData = {
                            message: 'Task marked completed.  Would you like to schedule another call for the future?',
                            options: [],
                            callTask: true
                        };
                        $scope.followUpDialogResult = {
                            callTask: {
                                subject: followUpTask.subject + ' call',
                                date: dateTwoDaysFromToday
                            }
                        };

                        $scope.followUpSaveFunc = function(){
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Ask in Future'
                                    }
                                });
                            });

                            //Create Call Task
                            if($scope.followUpDialogResult.createCallTask){
                                createCallTask(contactsObject);
                            }

                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }else if(taskResult === 'Partner - Financial' && followUpTask.contacts.length > 0){

                        $scope.followUpDialogData = {
                            message: 'Contact\'s status will be updated to \'Partner - Financial\'.',
                            options: [],
                            thankTask: true,
                            financialCommitment: true,
                            givingTask: true,
                            newsletter: true
                        };
                        $scope.followUpDialogResult = {
                            thankTask: {
                                subject: followUpTask.subject + ' thank you',
                                date: dateTwoDaysFromToday
                            },
                            givingTask: {
                                subject: followUpTask.subject + ' setup giving',
                                date: dateTwoDaysFromToday
                            }
                        };

                        $scope.followUpSaveFunc = function(){
                            if(angular.isUndefined($scope.followUpDialogResult.financialCommitment)){
                                alert('Please enter financial commitment information.');
                                return;
                            }
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Partner - Financial',
                                        pledge_amount: $scope.followUpDialogResult.financialCommitment.amount,
                                        pledge_frequency: $scope.followUpDialogResult.financialCommitment.frequency,
                                        pledge_start_date: $scope.followUpDialogResult.financialCommitment.date
                                    }
                                });

                                //Newsletter signup
                                if($scope.followUpDialogResult.newsletterSignup){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            send_newsletter: $scope.followUpDialogResult.newsletter.type
                                        }
                                    });
                                }
                            });

                            //Create Thank Task
                            if($scope.followUpDialogResult.createThankTask){
                                createThankTask(contactsObject);
                            }

                            //Create Giving Task
                            if($scope.followUpDialogResult.createGivingTask){
                                createGivingTask(contactsObject);
                            }
                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }else if(taskResult === 'Partner - Special' && followUpTask.contacts.length > 0){

                        $scope.followUpDialogData = {
                            message: 'Contact\'s status will be updated to \'Partner - Special\'.',
                            options: [],
                            thankTask: true,
                            financialCommitment: false,
                            givingTask: true,
                            newsletter: true
                        };
                        $scope.followUpDialogResult = {
                            thankTask: {
                                subject: followUpTask.subject + ' thank you',
                                date: dateTwoDaysFromToday
                            },
                            givingTask: {
                                subject: followUpTask.subject + ' setup giving',
                                date: dateTwoDaysFromToday
                            }
                        };

                        $scope.followUpSaveFunc = function(){
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Partner - Special'
                                    }
                                });

                                //Newsletter signup
                                if($scope.followUpDialogResult.newsletterSignup){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            send_newsletter: $scope.followUpDialogResult.newsletter.type
                                        }
                                    });
                                }
                            });

                            //Create Thank Task
                            if($scope.followUpDialogResult.createThankTask){
                                createThankTask(contactsObject);
                            }

                            //Create Giving Task
                            if($scope.followUpDialogResult.createGivingTask){
                                createGivingTask(contactsObject);
                            }
                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }else if(taskResult === 'Partner - Pray' && followUpTask.contacts.length > 0){

                        $scope.followUpDialogData = {
                            message: 'Contact\'s status will be updated to \'Partner - Pray\'.',
                            options: [],
                            thankTask: false,
                            financialCommitment: false,
                            givingTask: false,
                            newsletter: true
                        };

                        $scope.followUpSaveFunc = function(){
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Partner - Pray'
                                    }
                                });

                                //Newsletter signup
                                if($scope.followUpDialogResult.newsletterSignup){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            send_newsletter: $scope.followUpDialogResult.newsletter.type
                                        }
                                    });
                                }
                            });
                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }else if(taskResult === 'Ask in Future' && followUpTask.contacts.length > 0){

                        $scope.followUpDialogData = {
                            message: 'Contact\'s status will be updated to \'Ask in Future\'.',
                            options: [],
                            callTask: true,
                            newsletter: true
                        };
                        $scope.followUpDialogResult = {
                            callTask: {
                                subject: followUpTask.subject + ' call',
                                date: dateTwoDaysFromToday
                            }
                        };

                        $scope.followUpSaveFunc = function(){
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Ask in Future'
                                    }
                                });

                                //Newsletter signup
                                if($scope.followUpDialogResult.newsletterSignup){
                                    api.call('put', 'contacts/' + c, {
                                        contact: {
                                            send_newsletter: $scope.followUpDialogResult.newsletter.type
                                        }
                                    });
                                }
                            });

                            //Create Call Task
                            if($scope.followUpDialogResult.createCallTask){
                                createCallTask(contactsObject);
                            }

                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }else if(taskResult === 'Not Interested' && followUpTask.contacts.length > 0){

                        $scope.followUpDialogData = {
                            message: 'Contact\'s status will be updated to \'Not Interested\'.',
                            options: []
                        };

                        $scope.followUpSaveFunc = function(){
                            //Contact Updates
                            angular.forEach(followUpTask.contacts, function(c){
                                api.call('put', 'contacts/' + c, {
                                    contact: {
                                        status: 'Not Interested'
                                    }
                                });
                            });

                            jQuery('#complete_task_followup_modal').dialog('close');
                        };

                    }




                    if(angular.isDefined($scope.followUpDialogData)){
                        $scope.followUpDialogResult.select = $scope.followUpDialogData.options[0];
                        $scope.$apply();
                        jQuery("#complete_task_followup_modal").dialog({
                            autoOpen: true,
                            modal: true
                        });

                        jQuery('.followUpDialogDatepicker').datepicker({ dateFormat: 'yy-mm-dd' });
                    }
                };


                var createThankTask = function(contactsObject){
                    api.call('post', 'tasks/', {
                        task: {
                            start_at: $scope.followUpDialogResult.thankTask.date,
                            subject: $scope.followUpDialogResult.thankTask.subject,
                            activity_type: 'Thank',
                            activity_contacts_attributes: contactsObject,
                            activity_comments_attributes: {
                                "0": {
                                    body: $scope.followUpDialogResult.thankTask.comments
                                }
                            }
                        }
                    }, function () {
                        $scope.refreshVisibleTasks();
                    });
                };

                var createGivingTask = function(contactsObject){
                    api.call('post', 'tasks/', {
                        task: {
                            start_at: $scope.followUpDialogResult.givingTask.date,
                            subject: $scope.followUpDialogResult.givingTask.subject,
                            activity_type: $scope.followUpDialogResult.givingTask.type,
                            activity_contacts_attributes: contactsObject,
                            activity_comments_attributes: {
                                "0": {
                                    body: $scope.followUpDialogResult.givingTask.comments
                                }
                            }
                        }
                    }, function () {
                        $scope.refreshVisibleTasks();
                    });
                };

                var createCallTask = function(contactsObject){
                    api.call('post', 'tasks/', {
                        task: {
                            start_at: $scope.followUpDialogResult.callTask.date,
                            subject: $scope.followUpDialogResult.callTask.subject,
                            activity_type: 'Call',
                            activity_contacts_attributes: contactsObject,
                            activity_comments_attributes: {
                                "0": {
                                    body: $scope.followUpDialogResult.callTask.comments
                                }
                            }
                        }
                    }, function () {
                        $scope.refreshVisibleTasks();
                    });
                };
            }
        };
    });