import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Button } from 'react-bootstrap';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const Dashboard = () => {
  const { t } = useTranslation();
  const [stats, setStats] = useState({
    sitesCount: 0,
    keysCount: 0,
    issuedKeysCount: 0,
  });

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const sitesRes = await axios.get(`${API_URL}/sites/`);
        const keysRes = await axios.get(`${API_URL}/keys/`);
        const issuedKeys = keysRes.data.filter(key => key.is_issued);
        
        setStats({
          sitesCount: sitesRes.data.length,
          keysCount: keysRes.data.length,
          issuedKeysCount: issuedKeys.length,
        });
      } catch (error) {
        console.error('Error fetching stats:', error);
      }
    };
    
    fetchStats();
  }, []);

  return (
    <Container>
      <h1 className="mb-4">{t('dashboard.title')}</h1>
      
      <Row className="mb-4">
        <Col md={4}>
          <Card className="text-center mb-3">
            <Card.Body>
              <Card.Title>{t('dashboard.cards.sites')}</Card.Title>
              <Card.Text className="h2">{stats.sitesCount}</Card.Text>
              <Link to="/sites">
                <Button variant="primary">{t('common.view')}</Button>
              </Link>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={4}>
          <Card className="text-center mb-3">
            <Card.Body>
              <Card.Title>{t('dashboard.cards.keys')}</Card.Title>
              <Card.Text className="h2">{stats.keysCount}</Card.Text>
              <Link to="/keys">
                <Button variant="primary">{t('common.view')}</Button>
              </Link>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={4}>
          <Card className="text-center mb-3">
            <Card.Body>
              <Card.Title>{t('dashboard.cards.issuedKeys')}</Card.Title>
              <Card.Text className="h2">{stats.issuedKeysCount}</Card.Text>
              <Link to="/active">
                <Button variant="primary">{t('common.view')}</Button>
              </Link>
            </Card.Body>
          </Card>
        </Col>
      </Row>
      
      <Row className="mb-4">
        <Col md={6}>
          <Card>
            <Card.Body>
              <Card.Title>{t('dashboard.quickActions.title')}</Card.Title>
              <div className="d-grid gap-2">
                <Link to="/sites/add">
                  <Button variant="outline-primary" className="mb-2 w-100">{t('dashboard.quickActions.addSite')}</Button>
                </Link>
                <Link to="/keys/add">
                  <Button variant="outline-primary" className="mb-2 w-100">{t('dashboard.quickActions.addKey')}</Button>
                </Link>
                <Link to="/keys/issue">
                  <Button variant="outline-success" className="mb-2 w-100">{t('dashboard.quickActions.issueKey')}</Button>
                </Link>
                <Link to="/keys/return">
                  <Button variant="outline-warning" className="mb-2 w-100">{t('dashboard.quickActions.returnKey')}</Button>
                </Link>
                <Link to="/backup">
                  <Button variant="outline-secondary" className="mb-2 w-100">{t('dashboard.quickActions.backup')}</Button>
                </Link>
              </div>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={6}>
          <Card>
            <Card.Body>
              <Card.Title>{t('dashboard.about.title')}</Card.Title>
              <Card.Text>
                {t('dashboard.about.text1')}
              </Card.Text>
              <Card.Text>
                {t('dashboard.about.text2')}
              </Card.Text>
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default Dashboard;

