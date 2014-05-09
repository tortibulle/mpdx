angular.module('mpdxApp').controller('contactsController', function ($scope, $filter, $location, api, urlParameter, contactCache) {

    $scope.Math = window.Math;
    $scope.totalContacts = 0;

    $scope.contactQuery = {
        limit: 25,
        offset: 0,
        name: '',
        city: ['']
    };

    $scope.page = {
        current: 1,
        total: 1
    };

    $scope.$watch('contactQuery', function (q, oldq) {
        if(q.limit > oldq.limit){
            $scope.page = {
                current: 1,
                total: 1
            };
            return;
        }
        api.call('get','contacts?limit='+q.limit+
            '&offset=' + q.offset +
            '&filters[name]=' + encodeURIComponent(q.name) +
            '&filters[city]=' + encodeURIComponent('Orlando') +
            '&filters[city]=' + encodeURIComponent('LA')
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

            $scope.totalContacts = 35;

            $scope.page.total = Math.ceil($scope.totalContacts / q.limit);

            //console.log(q);
            console.log(data);
        }, null, true);
    }, true);

    $scope.$watch('page', function (p) {
        $scope.contactQuery.offset = ((p.current - 1) * $scope.contactQuery.limit);
        //console.log(p);
    }, true);
});