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
        $scope.contactQuery.type = 'person';
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
        expect($scope.contactQuery.type).toEqual('');
        expect($scope.contactQuery.city).toEqual(['']);
        expect($scope.contactQuery.state).toEqual(['']);
        expect($scope.contactQuery.newsletter).toEqual('');
        expect($scope.contactQuery.status).toEqual(['']);
        expect($scope.contactQuery.likely).toEqual(['']);
        expect($scope.contactQuery.church).toEqual(['']);
        expect($scope.contactQuery.referrer).toEqual(['']);
    });

    it('url array encode should encode vars', function() {
        var controller = createController();

        var array = ['Testing', '$T$%&^V3'];
        var encoded = encodeURLarray(array);

        expect(encoded[0]).toEqual('Testing');
        expect(encoded[1]).toEqual('%24T%24%25%26%5EV3');
    });
});