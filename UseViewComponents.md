While there isn't a single "official" application template that includes view components by default, the most popular and widely adopted approach is using the view_component gem created by GitHub. Many developers use a custom Rails template to quickly set up this gem and related configurations. 
ViewComponent
ViewComponent
 +4
Key Resources & Approaches
view_component gem: This is the de facto standard framework for building reusable, testable, and encapsulated UI components in Rails, providing an object-oriented approach to the view layer.
view_component-contrib template: A specific, community-driven template exists that extends the base gem with additional patterns and helpers. You can apply this to a new or existing Rails app using the command:
bash
rails app:template LOCATION="https://railsbytes.com/script/zJosO5"
This template provides a quick, interactive way to get started with view_component-contrib extensions.
Custom Templates: Many teams and companies, such as Aha! software and GitHub, build their own internal application templates that include the view_component gem and specific configurations (like integrating with Tailwind CSS or Stimulus) tailored to their development standards. 
YouTube
YouTube
 +4
Key Integrations for View Components
For a complete and modern application setup, popular integrations often found in templates or setup guides include:
Lookbook: A component library and documentation tool that helps you visually test and document your view components in isolation, similar to Storybook in other frontend ecosystems.
Tailwind CSS: A popular utility-first CSS framework that pairs well with the component-based structure of ViewComponents.
Stimulus: A modest JavaScript framework for connecting your HTML to JavaScript, often used in conjunction with ViewComponents for rich frontend interactions in a "Hotwire" stack. 
YouTube
YouTube
 +4
In summary, there is no single, universally popular "application template," but rather the widely adopted view_component gem, which is then incorporated into custom templates or installed manually to establish a component-based architecture.