Feature: Host Venue Management
  As a host
  I want to create and manage music venues
  So that I can host music queue sessions

  Background:
    Given I am logged in as a host
    And I have a venue named "The Blue" in "NYC" with capacity "100"

  Scenario: Host creates a new venue
    When I navigate to create a new venue
    And I fill in the venue form with:
      | Field    | Value        |
      | Name     | Club X       |
      | Location | Brooklyn     |
      | Capacity | 200          |
    And I click "Create Venue"
    Then I should see "Venue created successfully!"
    And the venue "Club X" should exist

  Scenario: Host starts a new session
    When I navigate to my venue "The Blue"
    And I click "Start New Session"
    Then I should see the session is "ACTIVE"
    And I should see a 6-digit join code
    And the join code should be displayed prominently

  Scenario: Host can copy join code
    When I navigate to my venue "The Blue"
    And I start a new session
    And I click the copy button
    Then the join code should be copied to clipboard

  Scenario: Host can regenerate join code
    When I navigate to my venue "The Blue"
    And I start a new session
    And I save the current join code
    And I click "Regenerate"
    Then the join code should be different
    And I should see "Code regenerated"

  Scenario: Host can pause session
    When I navigate to my venue "The Blue"
    And I start a new session
    And I click "Pause"
    Then the session should be paused
    And I should see "Session paused"

  Scenario: Host can end session
    When I navigate to my venue "The Blue"
    And I start a new session
    And I click "End Session"
    Then the session should be ended
    And I should see previous sessions listed