describe('contacts', function() {
    beforeEach(module('mpdxApp'));
    var $scope, $location, $rootScope, createController;

    beforeEach(inject(function($injector) {
        $location = $injector.get('$location');
        $rootScope = $injector.get('$rootScope');
        $httpBackend = $injector.get('$httpBackend');
        $scope = $rootScope.$new();

        var $controller = $injector.get('$controller');

        createController = function() {
            return $controller('contactsController', {
                '$scope': $scope
            });
        };
    }));


    it('reset filter should clear filters', function() {
        var controller = createController();

        $scope.contactQuery.tags = ['test'];
        $scope.contactQuery.name = 'Steve';
        $scope.contactQuery.type = ['test'];
        $scope.contactQuery.city = ['Green Bay'];
        $scope.contactQuery.state = ['WI'];
        $scope.contactQuery.newsletter = 'all';
        $scope.contactQuery.status = ['test'];
        $scope.contactQuery.likely = ['test'];
        $scope.contactQuery.church = ['First Church', 'Second Church'];
        $scope.contactQuery.referrer = ['-'];

        $scope.resetFilters();

        expect($scope.contactQuery.tags).toEqual(['']);
        expect($scope.contactQuery.name).toEqual('');
        expect($scope.contactQuery.type).toEqual(['']);
        expect($scope.contactQuery.city).toEqual(['']);
        expect($scope.contactQuery.state).toEqual(['']);
        expect($scope.contactQuery.newsletter).toEqual('');
        expect($scope.contactQuery.status).toEqual(['']);
        expect($scope.contactQuery.likely).toEqual(['']);
        expect($scope.contactQuery.church).toEqual(['']);
        expect($scope.contactQuery.referrer).toEqual(['']);
    });
    /*
    it('changing page should update the contactQuery', function() {
        var controller = createController();

        $httpBackend.when('GET', 'api/v1/users/me').respond({userId: 'userX'}, {'A-Token': 'xxx'});
        $scope.page.current = 2;
        $scope.$digest();
        expect($scope.contactQuery.page).toEqual(2);
    });
    
    */
});