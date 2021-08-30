import Button from 'react-bootstrap/Button';
import ButtonGroup from 'react-bootstrap/ButtonGroup'
import {FaLinkedin, FaGithub} from 'react-icons/fa'

function LinkBar() {
  return (
    <ButtonGroup>
        <Button href="https://www.linkedin.com/in/aahanaggarwal99/" variant = "primary">
            <FaLinkedin size={30} />
        </Button>
        <Button href="https://github.com/aahanaggarwal/" variant="dark">
            <FaGithub  size={30} />
        </Button>
    </ButtonGroup>
  );
}

export default LinkBar;