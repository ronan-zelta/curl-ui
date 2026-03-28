// Postman-matched HTTP method colors
export const METHOD_COLORS = {
  GET:     '#6bcb77',
  POST:    '#fbbf24',
  PUT:     '#4b8ef1',
  PATCH:   '#a78bfa',
  DELETE:  '#f87171',
  HEAD:    '#2dd4bf',
  OPTIONS: '#f472b6',
};

export function getMethodColor(method) {
  return METHOD_COLORS[method?.toUpperCase()] || '#888';
}
