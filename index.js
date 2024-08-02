const axios = require('axios');

async function fetchData() {
  try {
    const response = await axios.get('https://jsonplaceholder.typicode.com/todos/1');
    console.log(response.data);
  } catch (error) {
    console.error('Error fetching data:', error);
  }
}

fetchData();
