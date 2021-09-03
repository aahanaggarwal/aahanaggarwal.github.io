import React from "react";
import ReactDOM from "react-dom";
import "./index.css";
import Header from "./Header";
import WorkExp from "./WorkExp";
import LinkBar from "./LinkBar";
import Pictures from "./Pictures";
import Container from "react-bootstrap/Container";
import Row from "react-bootstrap/Row";
import Col from "react-bootstrap/Col";

import "bootstrap/dist/css/bootstrap.min.css";

ReactDOM.render(
  <React.StrictMode>
    <Header />
    <Container>
      <Row>
        <LinkBar />
      </Row>
      <Row>
        <Col fluid>
          <Pictures />
        </Col>
        <Col fluid>
          <WorkExp />
        </Col>
      </Row>
    </Container>
  </React.StrictMode>,
  document.getElementById("root")
);
