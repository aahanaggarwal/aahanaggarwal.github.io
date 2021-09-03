import "./WorkExp.css";
import ListGroup from "react-bootstrap/ListGroup";
import Accordian from "react-bootstrap/Accordion";

let graphql = {
  title: "Software Engineering Intern",
  buttonText: "SWE Intern - GraphQL Build Infra",
  company: "Facebook, GraphQL Build Infrastructure",
  startDate: "May 2021",
  endDate: "August 2021",
  bullets: [
    "Built a compiler to create C++ classes for GraphQL queries and fragments in order to use response data in a type safe and consistent way.",
    "Added integration tests using BUCK and bazel by using the compiler to generate C++ code, compile the generated code and test it against mocked data.",
    "Create a proof-of-concept demo by translating an existing C++ library using GraphQL to use the generated C++ classes.",
  ],
};

let whatsapp = {
  title: "Software Engineering Intern",
  buttonText: "SWE Inter - WhatsApp Core Infra",
  company: "Facebook, Whatsapp Core Infrastructure",
  startDate: "May 2020",
  endDate: "August 2020",
  bullets: [
    "Worked on improving the interface of an Erlang mock-client for WhatsApp according to spec.",
    "Wrote integration tests with the mock-client to reduce test running times from ~10m to 30s.",
    "Created a production monitoring application that would periodically check for regressions and crashes in WhatsApp servers and store the latency data for long term use.",
  ],
};

let catme = {
  title: "Software Engineer Summer Intern",
  buttonText: "SWE Intern - CATME",
  company: "CATME Smarter Teamwork",
  startDate: "April 2019",
  endDate: "August 2019",
  bullets: [
    "Connected online web tool to multiple 3rd party systems to allow for automatic import and export of customer data using RESTful APIs and OAuth2.0.",
    "Facilitated testing with customers to help deploy API integrations using AWS instances.",
  ],
};

let haptik = {
  title: "Software Engineering Intern",
  buttonText: "SWE Intern - Haptik",
  company: "Haptik",
  startDate: "May 2018",
  endDate: "June 2018",
  bullets: [
    "Used Python Django framework to make the job postings page dynamic with a database.",
    "Developed a middle layer for connection between local chatbots and Skype and Google Assistant using Python to parse and display simple text and rich messages such as images or cards.",
  ],
};

function WorkExp() {
  function individualWorkExp(project, index) {
    const bullet_items = project.bullets.map((thing, index) => (
      <ListGroup.Item>{thing}</ListGroup.Item>
    ));
    return (
      <div>
        <Accordian>
          <Accordian.Item eventKey={index}>
            <Accordian.Header>{project.buttonText}</Accordian.Header>
            <Accordian.Body>
              <h3>
                {project.title} at {project.company} from {project.startDate} to{" "}
                {project.endDate}
              </h3>
              <ListGroup variant="flush">{bullet_items}</ListGroup>
            </Accordian.Body>
          </Accordian.Item>
        </Accordian>
      </div>
    );
  }

  return (
    <div>
      {individualWorkExp(graphql, "0")}
      {individualWorkExp(whatsapp, "1")}
      {individualWorkExp(catme, "2")}
      {individualWorkExp(haptik, "3")}
    </div>
  );
}

export default WorkExp;
