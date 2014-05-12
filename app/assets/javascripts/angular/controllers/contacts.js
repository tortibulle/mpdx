angular.module('mpdxApp').controller('contactsController', function ($scope, $filter, $location, api, urlParameter, contactCache) {

    $scope.totalContacts = 0;

    $scope.contactQuery = {
        limit: 25,
        page: 1,
        name: '',
        city: [''],
        state: [''],
        newsletter: '',
        tags: [''],
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

    //view preferences
    api.call('get','users/me', {}, function(data) {
        var prefs = data.user.preferences.contacts_filter[1];
        if(angular.isDefined(prefs.church)){
            $scope.contactQuery.church = prefs.church;
        }
        if(angular.isDefined(prefs.city)){
            $scope.contactQuery.city = prefs.city;
        }
        if(angular.isDefined(prefs.name)){
            $scope.contactQuery.name = prefs.name;
        }
        if(angular.isDefined(prefs.tags)){
            $scope.contactQuery.tags = prefs.tags.split(',');
        }

        $scope.contactQuery.viewPrefsLoaded = true;
        console.log(prefs);
    }, null, true);

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
        api.call('get','contacts?per_page='+q.limit+
            '&page=' + q.page +
            '&filters[name]=' + encodeURIComponent(q.name) +
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
                    contact: _.find(data.contacts, { 'id': contact.id })
                });
            });
            $scope.contacts = data.contacts;

            $scope.totalContacts = data.meta.total;
            $scope.page.total = data.meta.total_pages;
            $scope.page.from = data.meta.from;
            $scope.page.to = data.meta.to;
            console.log(data);

            //Save View Prefs
            var prefs = {
                user: {
                    preferences: {
                        contacts_filter:{
                            1:{
                                name: q.name,
                                city: q.city,
                                tags: ''
                            }
                        },
                        contacts_view_options: {}
                    }
                }
            };
            console.log(prefs);
            api.call('put','users/me', prefs);
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