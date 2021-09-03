import "./LinkBar.css";
import Button from "react-bootstrap/Button";
import ButtonGroup from "react-bootstrap/ButtonGroup";
import { FaLinkedin, FaGithub, FaTwitter, FaEnvelope } from "react-icons/fa";

function LinkBar() {
  return (
    <ButtonGroup>
      <style type="text/css">
        {`
        .btn-twitter {
          background-color: #1DA1F2;
          color: white;
        }
        .btn-github {
          background-color: #171515;
          color: white;
        }
        .btn-linkedin {
          background-color: #0077b5;
          color: white;
        }
        .btn-email {
          background-color: #991111;
          color: white;
        }
        `}
      </style>
      <Button
        href="https://www.linkedin.com/in/aahanaggarwal99/"
        variant="linkedin"
      >
        <FaLinkedin size={30} />
      </Button>
      <Button href="https://github.com/aahanaggarwal/" variant="github">
        <FaGithub size={30} />
      </Button>
      <Button href="https://twitter.com/aahanaggarwal" variant="twitter">
        <FaTwitter size={30} />
      </Button>
      <Button href="mailto:aahan@aahan.dev" variant="email">
        <FaEnvelope size={30} />
      </Button>
    </ButtonGroup>
  );
}

export default LinkBar;
