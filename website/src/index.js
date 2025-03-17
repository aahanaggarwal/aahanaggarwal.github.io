import React from "react";
import ReactDOM from "react-dom";
import "./index.css";

import "bootstrap/dist/css/bootstrap.min.css";

ReactDOM.render(
  <React.StrictMode>
    <p>
      Hi, my name is Aahan Aggarwal.<br/>
      I'm from Mumbai, and I like computers.<br/>
      You can contact me at <a href="mailto:me@aahan.dev">me@aahan.dev</a>.
    </p>

    <p>
      Present:<br/>
      Working as a software engineer on the Mobile GraphQL Runtime team at Meta.
    </p>
    <p>
      Past:<br/>
      Worked as a software engineer on Release Infrastructure for AR/VR devices at Meta.
      Completed my Master's in CS at <a href="https://www.purdue.edu">Purdue University</a>.
      Interned at <a href="https://about.facebook.com/meta">Meta</a> - GraphQL Build Infra and WhatsApp Core Infrastructure teams.<br/>
      Completed my Bachelor's in CS at Purdue University.
    </p>

    <p>
      Some Links:<br/>
      <a href="https://www.linkedin.com/in/aahanaggarwal99/">LinkedIn</a><br/>
      <a href="https://twitter.com/aahanaggarwal">Twitter</a><br/>
      <a href="https://github.com/aahanaggarwal/">GitHub</a><br/>
      <a href="https://www.instagram.com/aahan.aggarwal99/">Instragram</a><br/>
    </p>
  </React.StrictMode>,
  document.getElementById("root")
);
