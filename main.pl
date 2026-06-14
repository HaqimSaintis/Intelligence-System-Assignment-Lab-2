% =======================================================================
% CAI20103 INTELLIGENT SYSTEMS - LAB 2 (EXTENDED SYSTEM)
% TITLE: AI-Driven Intelligent Decision Support for Mental Health Wellbeing Among Youth
% INTEGRATION: NLP -> Risk Detection -> Decision -> STRIPS Planning
% SCENARIO: Assigning counsellors or mentors based on availability and case urgency.
% BY: Muhammad Harish Haqim Bin Adnan (012025020434) [BCS]
% =======================================================================

% Allow tokens to be dynamically added and removed during runtime
:- dynamic token/2.

% -----------------------------------------------------------------------
% PART A: NLP FOR INTELLIGENT INPUT PROCESSING
% -----------------------------------------------------------------------

% Task A1: Text Representation (6 Test Cases)
input_text(t1, "I feel completely hopeless and deep in depression.").
input_text(t2, "I am completely hopeless recently.").
input_text(t3, "I am okay but sometimes feel anxious and alone.").
input_text(t4, "I am very anxious.").
input_text(t5, "I feel very stressed and overwhelmed lately.").
input_text(t6, "I feel sometimes overwhelmed with everything.").

% Task A2: Tokenization
% This rule takes the string, makes it lowercase, splits it by spaces/punctuation, and saves each word as a dynamic token fact.
tokenize_input(TextID) :-
    input_text(TextID, String),
    string_lower(String, Lower),
    split_string(Lower, " ,.", " ,.", StrList),
    maplist(atom_string, AtomList, StrList),
    retractall(token(TextID, _)),
    assert_tokens(TextID, AtomList).

assert_tokens(_, []).
assert_tokens(TextID, [Word|Rest]) :-
    assertz(token(TextID, Word)),
    assert_tokens(TextID, Rest).

% Task A2: Keyword Extraction Rules
issue_keyword(depression, hopeless).
issue_keyword(depression, depression).
issue_keyword(anxiety, anxious).
issue_keyword(anxiety, alone).
issue_keyword(stress, stressed).
issue_keyword(stress, overwhelmed).

severity_keyword(high, very).
severity_keyword(high, completely).
severity_keyword(high, deep).
severity_keyword(medium, sometimes).
severity_keyword(medium, okay).

% Task A3: Basic Parsing & Meaning Extraction
extract_issue(TextID, Issue, MatchedWord) :- 
    token(TextID, MatchedWord),
    issue_keyword(Issue, MatchedWord),
    !.

extract_severity(TextID, Severity, MatchedWord) :- 
    token(TextID, MatchedWord),
    severity_keyword(Severity, MatchedWord),
    !.

extract_severity(_, low, 'none-detected'). % Default fallback if no severity words are used

% -----------------------------------------------------------------------
% LAB 1 INTEGRATION: PROBABILISTIC RISK & CSP DECISION
% -----------------------------------------------------------------------

% Probabilities
probability_actual_risk(depression, high, 0.95).   
probability_actual_risk(depression, medium, 0.70). 
probability_actual_risk(depression, low, 0.30).    

probability_actual_risk(anxiety, high, 0.90).   
probability_actual_risk(anxiety, medium, 0.65). 
probability_actual_risk(anxiety, low, 0.25).    

probability_actual_risk(stress, high, 0.85).   
probability_actual_risk(stress, medium, 0.60). 
probability_actual_risk(stress, low, 0.20).

% Urgency Categorization
categorize_urgency(critical, Prob) :-
    Prob >= 0.75.
categorize_urgency(moderate, Prob) :-
    Prob >= 0.40, Prob < 0.75.
categorize_urgency(low, Prob) :-
    Prob < 0.40.

% Counsellors Database
counsellor(c1, 'Dr. Aisyah', depression, available, 2).
counsellor(c2, 'Mr. Akmal', stress, available, 2).
counsellor(c3, 'Ms. Sakinah', anxiety, available, 1).
counsellor(c4, 'Mr. Amir', general, available, 0).
counsellor(c5, 'Dr. Faris', general, unavailable, 3).

% Counsellor validation
valid_counsellor(CounsellorID, CounsellorName, Specialization, Issue) :-
    counsellor(CounsellorID, CounsellorName, Specialization, available, _),
    (Specialization = Issue ; Specialization = general).

% Check availability of counsellor
available_counsellor(CounsellorID, Name, Specialization, Caseload) :-
    counsellor(CounsellorID, Name, Specialization, available, Caseload),
    Caseload < 4.

% -----------------------------------------------------------------------
% PART B: AUTOMATED PLANNING & DECISION MAKING (STRIPS)
% -----------------------------------------------------------------------

% Task B1 & B3: STRIPS Representation (Combined with Scheduling Strategy)
% Format: action(Name, Preconditions, AddList, DeleteList)
action(assign_counsellor, 
       [risk_detected, no_support], 
       [has_support], 
       [no_support]).

action(schedule_immediate_session, 
       [has_support, critical], 
       [plan_complete], 
       []).

action(schedule_standard_session, 
       [has_support, moderate], 
       [plan_complete], 
       []).
action(schedule_followup, 
       [has_support, low], 
       [plan_complete], 
       []).

% Task B2: State-Space Planning (Search)
% subset/2 checks if all elements in List1 are in List2.
is_subset([], _).
is_subset([H|T], List) :- member(H, List), is_subset(T, List).

% Base case: We reach the goal.
plan(State, Goal, [], _) :- is_subset(Goal, State).

% Recursive step: Find an action, check preconditions, apply effects, repeat.
plan(State, Goal, [Action | RestPlan], Visited) :-
    action(Action, Preconditions, Add, Delete),
    is_subset(Preconditions, State),
    \+ member(Action, Visited), 
    subtract(State, Delete, TempState),
    union(TempState, Add, NextState),
    plan(NextState, Goal, RestPlan, [Action | Visited]).

% -----------------------------------------------------------------------
% SYSTEM PIPELINE EXECUTION & EXPLAINABILITY
% -----------------------------------------------------------------------

% Task A4 & B4: Execute Full Pipeline and Generate Explainable Output
process_case(TextID) :-
    % NLP Extraction
    input_text(TextID, RawText),
    tokenize_input(TextID),
    findall(Word, token(TextID, Word), TokensList),
    extract_issue(TextID, Issue, IssueKeyword),
    extract_severity(TextID, Severity, SeverityKeyword),
    
    % Logic (Risk & Matching)
    probability_actual_risk(Issue, Severity, RiskProb),
    categorize_urgency(UrgencyCat, RiskProb),
    valid_counsellor(CounsellorID, CounsellorName, Specialization, Issue),

    % Logic (Check counsellor availability)
    available_counsellor(CounsellorID, CounsellorName, Specialization, _),
    
    % Automated Planning
    InitialState = [risk_detected, no_support, UrgencyCat],
    Goal = [plan_complete],
    plan(InitialState, Goal, ActionPlan, []),
    
    % Print Output
    nl,
    writeln('=========================================='),
    writeln('            SYSTEM DECISION       '),
    writeln('=========================================='),
    write('Raw Text Input: "'), write(RawText), writeln('"'),
    write('Extracted Mean: Severity = '), write(Severity), write(', Issue = '), writeln(Issue),
    write('Tokens: '), writeln(TokensList),
    write('Matched Issue Keyword: '), writeln(IssueKeyword),
    write('Matched Severity Keyword: '), writeln(SeverityKeyword),
    write('Calculated Risk: '), write(RiskProb), write(' ('), write(UrgencyCat), writeln(')'),
    write('CSP Decision: Assigned to '), write(CounsellorName), write(' (ID: '), write(CounsellorID), write(') ('), write(Specialization), writeln(')'),
    writeln('------------------------------------------'),
    writeln('GENERATED ACTION PLAN:'),
    print_plan(ActionPlan),
    writeln('=========================================='),
    !. % Cut to prevent backtracking and multiple outputs

% Helper to print the plan steps clearly
print_plan([]).
print_plan([Action|Rest]) :-
    write(' -> '), writeln(Action),
    print_plan(Rest).