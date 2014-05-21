angular.module('mpdxApp').controller('contactsController', function ($scope, $filter, $location, api, urlParameter, contactCache) {
    var viewPrefs;

    $scope.contactsLoading = true;
    $scope.totalContacts = 0;

    $scope.contactQuery = {
        limit: 25,
        page: 1,
        tags: [''],
        name: '',
        type: '',
        city: [''],
        state: [''],
        newsletter: '',
        status: [''],
        likely: [''],
        church: [''],
        referrer: [''],
        viewPrefsLoaded: false
    };

    $scope.page = {
        current: 1,
        total: 1,
        from: 0,
        to: 0
    };

    $scope.resetFilters = function(){
        $scope.contactQuery.tags = [''];
        $scope.contactQuery.name = '';
        $scope.contactQuery.type = '';
        $scope.contactQuery.city = [''];
        $scope.contactQuery.state = [''];
        $scope.contactQuery.newsletter = '';
        $scope.contactQuery.status = [''];
        $scope.contactQuery.likely = [''];
        $scope.contactQuery.church = [''];
        $scope.contactQuery.referrer = [''];
    };

    //view preferences
    api.call('get','users/me', {}, function(data) {
        viewPrefs = data;
        $scope.contactQuery.viewPrefsLoaded = true;

        if(angular.isUndefined(viewPrefs.user.preferences.contacts_filter)){
            var prefs = null;
            viewPrefs.user.preferences.contacts_filter = {};
        }else{
            var prefs = viewPrefs.user.preferences.contacts_filter[window.current_account_list_id];
        }

        if(_.isNull(prefs)){
            return;
        }
        if(angular.isDefined(prefs.tags)){
            $scope.contactQuery.tags = prefs.tags.split(',');
        }
        if(angular.isDefined(prefs.name)){
            $scope.contactQuery.name = prefs.name;
            if(prefs.name){
                jQuery("#leftmenu #filter_name").trigger("click");
            }
        }
        if(angular.isDefined(prefs.type)){
            $scope.contactQuery.type = prefs.type;
            if(prefs.type){
                jQuery("#leftmenu #filter_type").trigger("click");
            }
        }
        if(angular.isDefined(prefs.city)){
            $scope.contactQuery.city = prefs.city;
            if(prefs.city[0]){
                jQuery("#leftmenu #filter_city").trigger("click");
            }
        }
        if(angular.isDefined(prefs.state)){
            $scope.contactQuery.state = prefs.state;
            if(prefs.state[0]){
                jQuery("#leftmenu #filter_state").trigger("click");
            }
        }
        if(angular.isDefined(prefs.newsletter)){
            $scope.contactQuery.newsletter = prefs.newsletter;
            if(prefs.newsletter){
                jQuery("#leftmenu #filter_newsletter").trigger("click");
            }
        }
        if(angular.isDefined(prefs.status)){
            $scope.contactQuery.status = prefs.status;
            if(prefs.status[0]){
                jQuery("#leftmenu #filter_status").trigger("click");
            }
        }
        if(angular.isDefined(prefs.likely)){
            $scope.contactQuery.likely = prefs.likely;
            if(prefs.likely[0]){
                jQuery("#leftmenu #filter_likely").trigger("click");
            }
        }
        if(angular.isDefined(prefs.church)){
            $scope.contactQuery.church = prefs.church;
            if(prefs.church[0]){
                jQuery("#leftmenu #filter_church").trigger("click");
            }
        }
        if(angular.isDefined(prefs.referrer)){
            $scope.contactQuery.referrer = prefs.referrer;
            if(prefs.referrer[0]){
                jQuery("#leftmenu #filter_referrer").trigger("click");
            }
        }
    });

    $scope.tagIsActive = function(tag){
        return _.contains($scope.contactQuery.tags, tag);
    };

    $scope.tagClick = function(tag){
        if($scope.tagIsActive(tag)){
            _.remove($scope.contactQuery.tags, function(i) { return i === tag; });
            if($scope.contactQuery.tags.length === 0){
                $scope.contactQuery.tags.push('');
            }
        }else{
            _.remove($scope.contactQuery.tags, function(i) { return i === ''; });
            $scope.contactQuery.tags.push(tag);
        }
    };

    $scope.$watch('contactQuery', function (q, oldq) {
        if(!q.viewPrefsLoaded){
            return;
        }
        if(q.page === oldq.page){
            $scope.page.current = 1;
            if(q.page !== 1){
                return;
            }
        }
        $scope.contactsLoading = true;

        api.call('get','contacts?account_list_id=' + (window.current_account_list_id || '') +
            '&per_page=' + q.limit +
            '&page=' + q.page +
            '&filters[name]=' + encodeURIComponent(q.name) +
            '&filters[contact_type]=' + encodeURIComponent(q.type) +
            '&filters[city][]=' + encodeURLarray(q.city).join('&filters[city][]=') +
            '&filters[state][]=' + encodeURLarray(q.state).join('&filters[state][]=') +
            '&filters[newsletter]=' + encodeURIComponent(q.newsletter) +
            '&filters[tags][]=' + encodeURLarray(q.tags).join('&filters[tags][]=') +
            '&filters[status][]=' + encodeURLarray(q.status).join('&filters[status][]=') +
            '&filters[likely][]=' + encodeURLarray(q.likely).join('&filters[likely][]=') +
            '&filters[church][]=' + encodeURLarray(q.church).join('&filters[church][]=') +
            '&filters[referrer][]=' + encodeURLarray(q.referrer).join('&filters[referrer][]=')
            , {}, function(data) {
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
                    phone_numbers: data.phone_numbers
                });
            });
            $scope.contacts = data.contacts;

            $scope.totalContacts = data.meta.total;
            $scope.page.total = data.meta.total_pages;
            $scope.page.from = data.meta.from;
            $scope.page.to = data.meta.to;

            $scope.contactsLoading = false;

            //Save View Prefs
            viewPrefs['user']['preferences']['contacts_filter'][window.current_account_list_id] = {
                tags: q.tags.join(),
                name: q.name,
                type: q.type,
                city: q.city,
                state: q.state,
                newsletter: q.newsletter,
                status: q.status,
                likely: q.likely,
                church: q.church,
                referrer: q.referrer
            };
            api.call('put','users/me', viewPrefs);
        }, null, true);
    }, true);

    $scope.$watch('page', function (p) {
        $scope.contactQuery.page = p.current;
    }, true);
});


function encodeURLarray(array){
    var encoded = [];
    angular.forEach(array, function(value, key){
        encoded.push(encodeURIComponent(value));
    });
    return encoded;
}