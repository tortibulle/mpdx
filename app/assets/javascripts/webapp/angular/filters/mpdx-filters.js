'use strict';

/* Filters */

angular.module('mpdxFilters', []).filter('startFrom', function() {
    return function(input, start) {
        start = +start; //parse to int
        if (input != undefined)
          return input.slice(start);
        else
          return [];
    }
});
