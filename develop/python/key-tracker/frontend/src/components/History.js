import React, { useState, useEffect } from 'react';
import { Container, Table, Form, Alert } from 'react-bootstrap';
import axios from 'axios';

const API_URL = '/api';

const History = () => {
  const [history, setHistory] = useState([]);
  const [sites, setSites] = useState([]);
  const [selectedSite, setSelectedSite] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    fetchSites();
    fetchHistory();
  }, []);
  
  useEffect(() => {
    fetchHistory(selectedSite);
  }, [selectedSite]);
  
  const fetchSites = async () => {
    try {
      const response = await axios.get(`${API_URL}/sites/`);
      setSites(response.data);
    } catch (err) {
      console.error('Error fetching sites:', err);
      setError('Помилка при завантаженні списку об\'єктів.');
    }
  };
  
  const fetchHistory = async (siteCode = '') => {
    try {
      setLoading(true);
      const url = siteCode 
        ? `${API_URL}/history/?site_code=${siteCode}` 
        : `${API_URL}/history/`;
      
      const response = await axios.get(url);
      
      // Отримати додаткову інформацію про ключі
      const keysResponse = await axios.get(`${API_URL}/keys/`);
      
      // Збагатити історію даними про ключі та об'єкти
      const historyWithDetails = await Promise.all(
        response.data.map(async (entry) => {
          const key = keysResponse.data.find(k => k.key_id === entry.key_id);
          
          return {
            ...entry,
            site_code: key ? key.site_code : 'Невідомий',
            description: key ? key.description : 'Невідомий ключ'
          };
        })
      );
      
      setHistory(historyWithDetails);
      setError(null);
    } catch (err) {
      console.error('Error fetching history:', err);
      setError('Помилка при завантаженні історії. Спробуйте пізніше.');
    } finally {
      setLoading(false);
    }
  };
  
  const handleSiteChange = (e) => {
    setSelectedSite(e.target.value);
  };
  
  return (
    <Container>
      <h1 className="mb-4">Історія ключів</h1>
      
      <Form.Group className="mb-4">
        <Form.Label>Фільтр за об'єктом</Form.Label>
        <Form.Select
          value={selectedSite}
          onChange={handleSiteChange}
        >
          <option value="">Всі об'єкти</option>
          {sites.map((site) => (
            <option key={site.site_id} value={site.site_code}>
              {site.site_code} - {site.address}
            </option>
          ))}
        </Form.Select>
      </Form.Group>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {loading ? (
        <p>Завантаження...</p>
      ) : history.length === 0 ? (
        <Alert variant="info">Історія відсутня.</Alert>
      ) : (
        <Table striped bordered hover responsive>
          <thead>
            <tr>
              <th>ID</th>
              <th>Об'єкт</th>
              <th>Опис ключа</th>
              <th>Кому видано</th>
              <th>Дата та час видачі</th>
              <th>Дата та час повернення</th>
              <th>Примітки</th>
            </tr>
          </thead>
          <tbody>
            {history.map((entry) => (
              <tr key={entry.history_id}>
                <td>{entry.history_id}</td>
                <td>{entry.site_code}</td>
                <td>{entry.description}</td>
                <td>{entry.issued_to || '-'}</td>
                <td>{entry.issued_at ? new Date(entry.issued_at).toLocaleString() : '-'}</td>
                <td>
                  {entry.returned_at 
                    ? new Date(entry.returned_at).toLocaleString() 
                    : <span className="text-warning">Не повернуто</span>}
                </td>
                <td>{entry.memo || '-'}</td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Container>
  );
};

export default History;
