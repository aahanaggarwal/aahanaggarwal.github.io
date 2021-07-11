import './Project.css';

let project1 = {
  "title": "Aahan",
  "dates": "aahahha",
  "bullets": [1, 2]
};

function individualProject(project) {
  const bullet_items = project.bullets.map((thing) => <li>I did {thing}</li>);
  return (
    <div className="project">
      <h3>
        {project.title} from {project.dates}
      </h3>
      <ul>{bullet_items}</ul>
    </div>
  );
}

function Project() {
  
  return (individualProject(project1));
}

export default Project;