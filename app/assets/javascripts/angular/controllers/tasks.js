angular.module('mpdxApp').controller('tasksController', function ($scope, $filter, $location, api, urlParameter, contactCache) {
    $scope.refreshTasks = function(){
        api.call('get','tasks?filters[completed]=false',{},function(tData) {
            api.call('get','contacts?filters[ids]='+_.uniq(_.flatten(tData.tasks, 'contacts')).join(),{},function(data) {
                angular.forEach(data.contacts, function(contact){
                    contactCache.update(contact.id, {
                        addresses: data.addresses,
                        email_addresses: data.email_addresses,
                        contact: _.find(data.contacts, { 'id': contact.id })
                    });
                });

                $scope.tasks = tData.tasks;
                $scope.comments = tData.comments;
                $scope.people = tData.people;

                $scope.tags = _.sortBy(_.uniq(_.flatten(_.pluck($scope.tasks, 'tag_list'))));
                $scope.tags = _.zip($scope.tags, $scope.tags);
                $scope.tags.unshift(['', '-- Any --']);

                $scope.activity_types = _.sortBy(_.uniq(_.pluck($scope.tasks, 'activity_type')));
                _.remove($scope.activity_types, function(action) { return action === ''; });
                $scope.activity_types = _.zip($scope.activity_types, $scope.activity_types);
                $scope.activity_types.unshift(['', '-- Any --']);

                $scope.contactStatusOptions = [['', '-- Any --']];
                $scope.contactLikelyToGiveOptions = [['', '-- Any --']];
                var contactTagPreOptions = [];

                angular.forEach(_.uniq(_.flatten($scope.tasks, 'contacts')), function(contact){
                    contactCache.get(contact, function(contact){
                        //contact tag list
                        contactTagPreOptions = _.sortBy(_.uniq(_.union(contactTagPreOptions, _.flatten(contact.contact.tag_list))));
                        $scope.contactTagOptions = _.zip(contactTagPreOptions, contactTagPreOptions);
                        $scope.contactTagOptions.unshift(['', '-- Any --']);

                        //contact status
                        if(angular.isUndefined(_.find($scope.contactStatusOptions, function(i){ return i[0] === contact.contact.status; }))){
                            $scope.contactStatusOptions.push([contact.contact.status, contact.contact.status]);
                            $scope.contactStatusOptions = _.sortBy($scope.contactStatusOptions, function(i) { return i[0]; });
                        }

                        //contact likely to give
                        if(angular.isUndefined(_.find($scope.contactLikelyToGiveOptions, function(i){ return i[0] === contact.contact.likely_to_give; }))){
                            $scope.contactLikelyToGiveOptions.push([contact.contact.likely_to_give, contact.contact.likely_to_give]);
                            $scope.contactLikelyToGiveOptions = _.sortBy($scope.contactLikelyToGiveOptions, function(i) { return i[0]; });
                        }
                    });
                });
            });
        });
    };
    $scope.refreshTasks();
    $scope.filterContactsSelect = [(urlParameter.get('contact_ids') || '')];
    $scope.filterContactCitySelect = [''];
    $scope.filterContactStateSelect = [''];
    $scope.filterContactNewsletterSelect = '';
    $scope.filterContactStatusSelect = [''];
    $scope.filterContactLikelyToGiveSelect = [''];
    $scope.filterContactChurchSelect = [''];
    $scope.filterContactReferrerSelect = [''];
    $scope.filterContactTagSelect = [''];
    $scope.filterTagsSelect = [''];
    $scope.filterActionSelect = [''];
    $scope.filterPage = ($location.$$url === '/starred' ? "starred" : 'active');

    //auto-open contact filter
    if($scope.filterContactsSelect[0]){
        jQuery("#leftmenu ul.left_filters li #contact").trigger("click");
    }

    $scope.tagIsActive = function(tag){
        return _.contains($scope.filterTagsSelect, tag);
    };

    $scope.contactTagIsActive = function(tag){
        return _.contains($scope.filterContactTagSelect, tag);
    };

    $scope.tagClick = function(tag){
        if($scope.tagIsActive(tag)){
            _.remove($scope.filterTagsSelect, function(i) { return i === tag; });
            if($scope.filterTagsSelect.length === 0){
                $scope.filterTagsSelect.push('');
            }
        }else{
            _.remove($scope.filterTagsSelect, function(i) { return i === ''; });
            $scope.filterTagsSelect.push(tag);
        }
    };

    $scope.contactTagClick = function(tag){
        if($scope.contactTagIsActive(tag)){
            _.remove($scope.filterContactTagSelect, function(i) { return i === tag; });
            if($scope.filterContactTagSelect.length === 0){
                $scope.filterContactTagSelect.push('');
            }
        }else{
            _.remove($scope.filterContactTagSelect, function(i) { return i === ''; });
            $scope.filterContactTagSelect.push(tag);
        }
    };

    $scope.filters = function(task){
        var filterContact = false;
        if($scope.filterContactsSelect[0] === '' || $scope.filterContactsSelect.length === 0){
            filterContact = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.contains($scope.filterContactsSelect, contact.toString())){
                    filterContact = true;
                }
            });
        }

        var filterContactCity = false;
        if($scope.filterContactCitySelect[0] === '' || $scope.filterContactCitySelect.length === 0){
            filterContactCity = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.intersection(_.flatten(contactCache.getFromCache(contact).addresses, 'city'), $scope.filterContactCitySelect).length > 0){
                    filterContactCity = true;
                }
            });
        }

        var filterContactState = false;
        if($scope.filterContactStateSelect[0] === '' || $scope.filterContactStateSelect.length === 0){
            filterContactState = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.intersection(_.flatten(contactCache.getFromCache(contact).addresses, 'state'), $scope.filterContactStateSelect).length > 0){
                    filterContactState = true;
                }
            });
        }

        var filterContactNewsletters = false;
        if($scope.filterContactNewsletterSelect === ''){
            filterContactNewsletters = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if($scope.filterContactNewsletterSelect === contactCache.getFromCache(contact).contact.send_newsletter){
                    filterContactNewsletters = true;
                }
            });
        }

        var filterContactStatus = false;
        if($scope.filterContactStatusSelect[0] === '' || $scope.filterContactStatusSelect.length === 0){
            filterContactStatus = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.contains($scope.filterContactStatusSelect, contactCache.getFromCache(contact).contact.status)){
                    filterContactStatus = true;
                }
            });
        }

        var filterContactLikelyToGive = false;
        if($scope.filterContactLikelyToGiveSelect[0] === '' || $scope.filterContactLikelyToGiveSelect.length === 0){
            filterContactLikelyToGive = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.contains($scope.filterContactLikelyToGiveSelect, contactCache.getFromCache(contact).contact.likely_to_give)){
                    filterContactLikelyToGive = true;
                }
            });
        }

        var filterContactChurch = false;
        if($scope.filterContactChurchSelect[0] === '' || $scope.filterContactChurchSelect.length === 0){
            filterContactChurch = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.contains($scope.filterContactChurchSelect, contactCache.getFromCache(contact).contact.church_name)){
                    filterContactChurch = true;
                }
            });
        }

        var filterContactReferrer = false;
        if($scope.filterContactReferrerSelect[0] === '' || $scope.filterContactReferrerSelect.length === 0){
            filterContactReferrer = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                var referralsStrings = [];
                angular.forEach(contactCache.getFromCache(contact).contact.referrals_to_me_ids, function(id){
                    referralsStrings.push(id.toString());
                });
                if(_.intersection(referralsStrings, $scope.filterContactReferrerSelect).length > 0){
                    filterContactReferrer = true;
                }
            });
        }

        var filterContactTag = false;
        if($scope.filterContactTagSelect[0] === '' || $scope.filterContactTagSelect.length === 0){
            filterContactTag = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.intersection(_.flatten(contactCache.getFromCache(contact).contact.tag_list), $scope.filterContactTagSelect).length > 0){
                    filterContactTag = true;
                }
            });
        }

        var filterTag = false;
        if(_.intersection(task.tag_list, $scope.filterTagsSelect).length > 0 || $scope.filterTagsSelect[0] === ''){
            filterTag = true;
        }

        var filterAction = false;
        if(_.contains($scope.filterActionSelect, task.activity_type) || $scope.filterActionSelect[0] === '' || $scope.filterActionSelect.length === 0){
            filterAction = true;
        }

        var filterPage = false;
        if($scope.filterPage === 'active'){
            filterPage = true;
        }else if($scope.filterPage === 'starred'){
            filterPage = task.starred;
        }

        return filterContact && filterContactCity && filterContactState && filterContactNewsletters && filterContactStatus && filterContactLikelyToGive && filterContactChurch && filterContactReferrer && filterContactTag && filterTag && filterAction && filterPage;
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