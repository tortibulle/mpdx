angular.module('mpdxApp').controller('tasksController', function ($scope, $filter, $location, api) {
    $scope.refreshTasks = function(){
        api.call('get','tasks',{},function(data) {
            $scope.tasks = _.remove(data.tasks, function(task) { return task.completed === false; });
            $scope.comments = data.comments;
            $scope.people = data.people;

            $scope.tags = _.sortBy(_.uniq(_.flatten(_.pluck($scope.tasks, 'tag_list'))));
            $scope.tags = _.zip($scope.tags, $scope.tags);
            $scope.tags.unshift(['', '-- Any --']);

            $scope.activity_types = _.sortBy(_.uniq(_.pluck($scope.tasks, 'activity_type')));
            _.remove($scope.activity_types, function(action) { return action === ''; });
            $scope.activity_types = _.zip($scope.activity_types, $scope.activity_types);
            $scope.activity_types.unshift(['', '-- Any --']);
        });
    };
    $scope.refreshTasks();
    $scope.filterContactsSelect = [''];
    $scope.filterTagsSelect = [''];
    $scope.filterActionSelect = [''];
    $scope.filterPage = ($location.$$url === '/starred' ? "starred" : 'active');

    $scope.$watch('filterActionSelect', function(newValue, oldValue){
        //console.log(newValue);
    })

    $scope.tagIsActive = function(tag){
        return _.contains($scope.filterTagsSelect, tag);
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

    $scope.filters = function(task){
        var filterContact = false;
        if($scope.filterContactsSelect[0] === ''){
            filterContact = true;
        }else{
            angular.forEach(task.contacts, function(contact){
                if(_.contains($scope.filterContactsSelect, contact.toString())){
                    filterContact = true;
                }
            });
        }

        var filterTag = false;
        if(_.intersection(task.tag_list, $scope.filterTagsSelect).length > 0 || $scope.filterTagsSelect[0] === ''){
            filterTag = true;
        }

        var filterAction = false;
        if(_.contains($scope.filterActionSelect, task.activity_type) || $scope.filterActionSelect[0] === ''){
            filterAction = true;
        }

        var filterPage = false;
        if($scope.filterPage === 'active'){
            filterPage = true;
        }else if($scope.filterPage === 'starred'){
            filterPage = task.starred;
        }
        return filterContact && filterTag && filterAction && filterPage;
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