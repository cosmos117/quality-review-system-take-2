import mongoose from "mongoose";

mongoose
  .connect(
    "mongodb+srv://qaiseransari:qaiseransari@cluster0.7uib7le.mongodb.net/qrp",
  )
  .then(async () => {
    console.log("Connected to MongoDB");

    const templates = await mongoose.connection.db
      .collection("templates")
      .find({})
      .toArray();
    console.log(`\nTotal templates: ${templates.length}\n`);

    templates.forEach((t, i) => {
      console.log(`Template ${i + 1}:`);
      console.log(`  _id: ${t._id}`);
      console.log(`  categories: ${t.defectCategories?.length || 0}`);
      console.log(`  createdAt: ${t.createdAt}`);

      // Show first few category IDs to check pattern
      if (t.defectCategories && t.defectCategories.length > 0) {
        console.log(`  First 3 category IDs:`);
        t.defectCategories.slice(0, 3).forEach((cat) => {
          console.log(`    ${cat._id} -> ${cat.name}`);
        });
      }
      console.log("");
    });

    // Now check for any category IDs starting with 6977555f
    console.log("Searching for old category ID pattern 6977555f...");
    const oldPattern = await mongoose.connection.db
      .collection("templates")
      .findOne({
        "defectCategories._id": { $regex: /^6977555f/ },
      });

    if (oldPattern) {
      console.log("Found old template!");
      console.log(JSON.stringify(oldPattern, null, 2));
    } else {
      console.log("No templates found with old category ID pattern");
    }

    process.exit(0);
  })
  .catch((err) => {
    console.error("Error:", err);
    process.exit(1);
  });
