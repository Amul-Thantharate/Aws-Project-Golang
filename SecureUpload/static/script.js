document.addEventListener("DOMContentLoaded", function () {
  const form = document.querySelector("form");
  const responseDiv = document.getElementById("response");

  form.addEventListener("submit", async function (e) {
    e.preventDefault();

    const formData = new FormData(form);
    responseDiv.textContent = "Uploading...";

    try {
      const res = await fetch("/upload", {
        method: "POST",
        body: formData
      });

      const text = await res.text();
      responseDiv.textContent = text;

      if (res.ok) {
        responseDiv.style.color = "green";
      } else {
        responseDiv.style.color = "red";
      }
    } catch (err) {
      responseDiv.textContent = "Upload failed.";
      responseDiv.style.color = "red";
    }
  });
});

