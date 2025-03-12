/**
 * Форматує дату в формат YYYY/DD/MM HH:MM
 * 
 * @param {string|Date} dateString - Дата у вигляді рядка або об'єкта Date
 * @returns {string} - Форматована дата
 */
export const formatDateTime = (dateString) => {
  if (!dateString) return '-';
  
  const date = new Date(dateString);
  
  // Перевірка на валідність дати
  if (isNaN(date.getTime())) return '-';
  
  // Отримання компонентів дати
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  
  // Форматування за вказаним шаблоном: YYYY/MM/DD HH:MM
  return `${year}/${month}/${day} ${hours}:${minutes}`;
};

