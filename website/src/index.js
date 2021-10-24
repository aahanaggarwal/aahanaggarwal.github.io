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
      Completing my Master's in CS at <a href="https://www.purdue.edu">Purdue University</a>.
    </p>
    <p>
      Past:<br/>
      Interned at <a href="https://www.facebook.com">Facebook</a> - GraphQL Build Infra and WhatsApp Core Infrastructure teams.<br/>
      Completed my Bachelor's in CS at Purdue University.
    </p>

    <p>
      Some Links:<br/>
      <a href="https://www.linkedin.com/in/aahanaggarwal99/">LinkedIn</a><br/>
      <a href="https://twitter.com/aahanaggarwal">Twitter</a><br/>
      <a href="https://github.com/aahanaggarwal/">GitHub</a><br/>
      <a href="https://purdue0-my.sharepoint.com/:b:/g/personal/aggarw57_purdue_edu/EWKoU2JbI9tPuukrEwmrxrwBwKZGagOMTgSlOcYRBgcGiw">Resume</a>
    </p>
  </React.StrictMode>,
  document.getElementById("root")
);
