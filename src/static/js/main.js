const toggleButton = document.querySelector(".site-header__toggle");
const navLinks = document.querySelectorAll(".site-nav a");
const revealNodes = document.querySelectorAll("[data-reveal]");

const setNavigationState = (isOpen) => {
    document.body.classList.toggle("nav-open", isOpen);
    if (toggleButton) {
        toggleButton.setAttribute("aria-expanded", String(isOpen));
    }
};

if (toggleButton) {
    toggleButton.addEventListener("click", () => {
        const nextState = toggleButton.getAttribute("aria-expanded") !== "true";
        setNavigationState(nextState);
    });
}

navLinks.forEach((link) => {
    link.addEventListener("click", () => setNavigationState(false));
});

if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
        (entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    entry.target.classList.add("revealed");
                    observer.unobserve(entry.target);
                }
            });
        },
        {
            threshold: 0.15,
        }
    );

    revealNodes.forEach((node) => observer.observe(node));
} else {
    revealNodes.forEach((node) => node.classList.add("revealed"));
}
