'use strict';

/* Controllers */

function ContactsIndex($scope, Contact) {
  $scope.pledge_frequencies = Contact.pledge_frequencies();
  $scope.data = Contact.query({}, function(data) {
    $.each(data.contacts, function(contact_index, contact) {
      $.each(contact.addresses, function(address_index, address_id) {
        data.contacts[contact_index].addresses[address_index] = $.grep(data.addresses, function(e){ return e.id == address_id; })[0];
      });
      $.each(contact.person_ids, function(people_index, person_id) {
        data.contacts[contact_index].person_ids[people_index] = $.grep(data.people, function(e){ return e.id == person_id; })[0];
      });
    });

    return data;
  });
  $scope.currentPage = 1;
  $scope.pageSize = 20;
  $scope.numberOfPages=function(){
        return Math.ceil(($scope.data.contacts ? $scope.data.contacts.length : 0)/$scope.pageSize);
    }

  $scope.setPage = function (pageNo) {
    $scope.currentPage = pageNo;
  };
}

function ContactsShow($scope, $routeParams, Contact, Donation) {
  $scope.pledge_frequencies = Contact.pledge_frequencies();
  $scope.data = Contact.get({contactId: $routeParams.contactId});
  $scope.donations = Donation.get({contactId: $routeParams.contactId});
}

function ContactsEdit($scope, $routeParams, Contact) {
  $scope.pledge_frequencies = Contact.pledge_frequencies();
  $scope.data = Contact.get({contactId: $routeParams.contactId});
}
