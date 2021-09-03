import "react-responsive-carousel/lib/styles/carousel.min.css"; // requires a loader
import Carousel  from "react-bootstrap/Carousel";
import grad_pic from "./grad_pic.jpg";
import "./Pictures.css";

function Pictures() {
  return (
    <Carousel variant="dark">
      <Carousel.Item>
        <img src={grad_pic} alt="First slide" className="pic" />
        <p className="legend">Legend 1</p>
      </Carousel.Item>
      <Carousel.Item>
        <img src="assets/2.jpeg" alt="First slide"/>
        <p className="legend">Legend 2</p>
      </Carousel.Item>
      <Carousel.Item>
        <img src="assets/3.jpeg" alt="First slide"/>
        <p className="legend">Legend 3</p>
      </Carousel.Item>
    </Carousel>
  );
}

export default Pictures;
