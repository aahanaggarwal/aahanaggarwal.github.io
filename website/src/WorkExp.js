import './WorkExp.css';

let whatsapp = {
  "title": "Software Engineering Intern",
  "company": "Facebook, Whatsapp Core Infrastructure",
  "startDate": "May 2020",
  "endDate": "August 2020",
  "bullets": [
    "Worked on improving the interface of an Erlang mock-client for WhatsApp according to spec.",
    "Wrote integration tests with the mock-client to reduce test running times from ~10m to 30s.",
    "Created a production monitoring application that would periodically check for regressions and crashes in WhatsApp servers and store the latency data for long term use."
  ]
};

let catme = {
  "title": "Software Engineer Summer Intern",
  "company": "CATME Smarter Teamwork",
  "startDate": "April 2019",
  "endDate": "August 2019",
  "bullets": [
    "Connected online web tool to multiple 3rd party systems to allow for automatic import and export of customer data using RESTful APIs and OAuth2.0.",
    "Facilitated testing with customers to help deploy API integrations using AWS instances."
  ]
}

let haptik = {
  "title": "Software Engineering Intern",
  "company": "Haptik",
  "startDate": "May 2018",
  "endDate": "June 2018",
  "bullets": [
    "Used Python Django framework to make the job postings page dynamic with a database.",
    "Developed a middle layer for connection between local chatbots and Skype and Google Assistant using Python to parse and display simple text and rich messages such as images or cards."
  ]
}

function individualWorkExp(project) {
  const bullet_items = project.bullets.map((thing) => <li>I did {thing}</li>);
  return (
    <div className="project">
      <h3>
        {project.title} at {project.company} from {project.startDate} to {project.endDate}
      </h3>
      <ul>{bullet_items}</ul>
    </div>
  );
}

function WorkExp() {

  return (
    <div>
      {individualWorkExp(whatsapp)}
      {individualWorkExp(catme)}
      {individualWorkExp(haptik)}
    </div>
  );
}

export default WorkExp;