'use strict';

/* Controllers */

function PeopleShow($scope, $routeParams, Person) {
  $scope.data = Person.get({contactId: $routeParams.contactId, personId: $routeParams.personId});
}
