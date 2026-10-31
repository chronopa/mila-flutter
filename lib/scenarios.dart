/// Ένα σενάριο συνομιλίας. Το prompt λέει στο AI ποιον ρόλο παίζει.
class Scenario {
  const Scenario(this.id, this.icon, this.title, this.prompt);

  final String id;
  final String icon;
  final String title;
  final String prompt;
}

const scenarios = <Scenario>[
  Scenario('free', '💬', 'Ελεύθερη συζήτηση',
      'Have a relaxed, friendly open conversation about whatever interests the learner.'),
  Scenario('int_devops', '🛠️', 'Interview: DevOps engineer',
      'ROLE-PLAY: You are a hiring manager interviewing the learner for a DevOps engineer position (CI/CD, containers, Kubernetes, cloud, monitoring, incident response). Ask ONE interview question at a time, mixing technical and behavioural questions, and follow up on their answers like a real interviewer.'),
  Scenario('int_backend', '⚙️', 'Interview: Backend engineer',
      'ROLE-PLAY: You are a hiring manager interviewing the learner for a backend engineer position (APIs, databases, system design, testing, performance). Ask ONE interview question at a time, mixing technical and behavioural questions, and follow up like a real interviewer.'),
  Scenario('int_behav', '🤝', 'Behavioral interview (STAR)',
      'ROLE-PLAY: You are an interviewer running a behavioural interview. Ask "Tell me about a time when..." questions one at a time and probe for the learner\'s specific actions and results.'),
  Scenario('standup', '📋', 'Daily stand-up',
      'ROLE-PLAY: You are the team lead running the daily stand-up. Ask what the learner did yesterday, what they plan today and any blockers, and ask short follow-up questions.'),
  Scenario('incident', '🚨', 'Εξήγηση incident',
      'ROLE-PLAY: You are a non-technical manager. The learner must explain a production incident (what happened, impact, root cause, fix, prevention) in clear simple English. Ask clarifying questions as a manager would.'),
  Scenario('present', '🎤', 'Παρουσίαση project / αρχιτεκτονικής',
      'ROLE-PLAY: You are a colleague from another team. The learner presents a system or project they worked on. Ask curious, probing questions about the design, trade-offs and challenges.'),
  Scenario('smalltalk', '☕', 'Small talk με συναδέλφους',
      'ROLE-PLAY: You are a friendly colleague chatting at the coffee machine. Keep it casual and natural: weekend, hobbies, news, work-life.'),
  Scenario('travel', '✈️', 'Ταξίδι (ξενοδοχείο, αεροδρόμιο, εστιατόριο)',
      'ROLE-PLAY: Act out a realistic travel situation (hotel check-in, restaurant, asking directions, airport) playing the local staff member. Switch to a new situation after a few turns.'),
  Scenario('custom', '✏️', 'Δικό σου σενάριο', ''),
];
