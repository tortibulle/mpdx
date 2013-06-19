//= require angular.min
//= require angular-resource
//= require angular-ui-bootstrap-tpls
//= require hamlcoffee
//= require jquery
//= require_tree ./lib
//= require_self
//= require_tree ./angular

var myApp = angular.module('mpdx', ['mpdxFilters', 'mpdxServices', 'ui.bootstrap'])
// As soon as possible.
.run(['$window', '$templateCache', function($window, $templateCache) {
  var templates = $window.JST,
      fileName,
      fileContent;

  for (fileName in templates) {
    fileContent = templates[fileName]();
    $templateCache.put(fileName, fileContent);
  }
}])
.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
      when('/dashboard', {templateUrl: 'webapp/angular/templates/dashboard/index', controller: DashboardIndex}).
      when('/contacts', {templateUrl: 'webapp/angular/templates/contacts/index', controller: ContactsIndex}).
      when('/contacts/:contactId', {templateUrl: 'webapp/angular/templates/contacts/show', controller: ContactsShow}).
      when('/contacts/:contactId/edit', {templateUrl: 'webapp/angular/templates/contacts/edit', controller: ContactsEdit}).
      when('/contacts/:contactId/people/:personId', {templateUrl: 'webapp/angular/templates/people/show', controller: PeopleShow}).
      otherwise({redirectTo: '/dashboard'})
}]);
